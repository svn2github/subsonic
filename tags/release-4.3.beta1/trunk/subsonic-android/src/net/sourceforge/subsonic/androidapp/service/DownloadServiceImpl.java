/*
 This file is part of Subsonic.

 Subsonic is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Subsonic is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Subsonic.  If not, see <http://www.gnu.org/licenses/>.

 Copyright 2009 (C) Sindre Mehus
 */
package net.sourceforge.subsonic.androidapp.service;

import java.io.File;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Collections;
import java.util.concurrent.CopyOnWriteArrayList;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Handler;
import android.os.IBinder;
import android.os.PowerManager;
import android.util.Log;
import net.sourceforge.subsonic.androidapp.R;
import net.sourceforge.subsonic.androidapp.domain.MusicDirectory;
import net.sourceforge.subsonic.androidapp.domain.PlayerState;
import net.sourceforge.subsonic.androidapp.util.CancellableTask;
import net.sourceforge.subsonic.androidapp.util.ShufflePlayBuffer;
import net.sourceforge.subsonic.androidapp.util.SimpleServiceBinder;
import net.sourceforge.subsonic.androidapp.util.Util;
import net.sourceforge.subsonic.androidapp.util.LRUCache;

import static net.sourceforge.subsonic.androidapp.domain.PlayerState.*;

/**
 * @author Sindre Mehus
 * @version $Id$
 */
public class DownloadServiceImpl extends Service implements DownloadService {

    private static final String TAG = DownloadServiceImpl.class.getSimpleName();
    private final IBinder binder = new SimpleServiceBinder<DownloadService>(this);
    private MediaPlayer mediaPlayer;
    private final List<DownloadFile> downloadList = new CopyOnWriteArrayList<DownloadFile>();
    private final Handler handler = new Handler();
    private final DownloadServiceLifecycleSupport lifecycleSupport = new DownloadServiceLifecycleSupport(this);
    private final ShufflePlayBuffer shufflePlayBuffer = new ShufflePlayBuffer(this);

    private final LRUCache<MusicDirectory.Entry, DownloadFile> downloadFileCache = new LRUCache<MusicDirectory.Entry, DownloadFile>(100);
    private final List<DownloadFile> cleanupCandidates = new ArrayList<DownloadFile>();
    private DownloadFile currentPlaying;
    private DownloadFile currentDownloading;
    private CancellableTask bufferTask;
    private PlayerState playerState = IDLE;
    private boolean shufflePlay;
    private long revision;
    private static DownloadService instance;
    private String suggestedPlaylistName;
    private PowerManager.WakeLock wakeLock;

    @Override
    public void onCreate() {
        super.onCreate();

        mediaPlayer = new MediaPlayer();
        mediaPlayer.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK);

        mediaPlayer.setOnErrorListener(new MediaPlayer.OnErrorListener() {
            @Override
            public boolean onError(MediaPlayer mediaPlayer, int what, int more) {
                handleError(new Exception("MediaPlayer error: " + what + " (" + more + ")"));
                return false;
            }
        });

        PowerManager pm = (PowerManager)getSystemService(Context.POWER_SERVICE);
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, this.getClass().getName());
        wakeLock.setReferenceCounted(false);

        instance = this;
        lifecycleSupport.onCreate();
    }

    @Override
    public void onStart(Intent intent, int startId) {
        super.onStart(intent, startId);
        lifecycleSupport.onStart(intent);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        lifecycleSupport.onDestroy();
        mediaPlayer.release();
        shufflePlayBuffer.shutdown();
        instance = null;
    }

    public static DownloadService getInstance() {
        return instance;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return binder;
    }

    @Override
    public synchronized void download(List<MusicDirectory.Entry> songs, boolean save, boolean autoplay) {
        shufflePlay = false;

        if (songs.isEmpty()) {
            return;
        }

        for (MusicDirectory.Entry song : songs) {
            DownloadFile downloadFile = new DownloadFile(this, song, save);
            downloadList.add(downloadFile);
        }
        revision++;

        if (autoplay) {
            play(0);
        } else {
            checkDownloads();
        }
        lifecycleSupport.serializeDownloadQueue();
    }

    @Override
    public synchronized void setShufflePlayEnabled(boolean enabled) {
        if (shufflePlay == enabled) {
            return;
        }

        shufflePlay = enabled;
        if (shufflePlay) {
            clear();
            checkDownloads();
        }
    }

    @Override
    public synchronized boolean isShufflePlayEnabled() {
        return shufflePlay;
    }

    @Override
    public synchronized void shuffle() {
        Collections.shuffle(downloadList);
        if (currentPlaying != null) {
            downloadList.remove(getCurrentPlayingIndex());
            downloadList.add(0, currentPlaying);
        }
        revision++;
    }

    @Override
    public synchronized DownloadFile forSong(MusicDirectory.Entry song) {
        for (DownloadFile downloadFile : downloadList) {
            if (downloadFile.getSong().equals(song)) {
                return downloadFile;
            }
        }

        DownloadFile downloadFile = downloadFileCache.get(song);
        if (downloadFile == null) {
            downloadFile = new DownloadFile(this, song, false);
            downloadFileCache.put(song, downloadFile);
        }
        return downloadFile;
    }

    @Override
    public synchronized void clear() {
        clear(true);
    }

    @Override
    public synchronized int size() {
        return downloadList.size();
    }

    public synchronized void clear(boolean serialize) {
        reset();
        downloadList.clear();
        revision++;
        if (currentDownloading != null) {
            currentDownloading.cancelDownload();
            currentDownloading = null;
        }
        setCurrentPlaying(null, false);

        if (serialize) {
            lifecycleSupport.serializeDownloadQueue();
        }
    }

    @Override
    public synchronized void remove(DownloadFile downloadFile) {
        if (downloadFile == currentDownloading) {
            currentDownloading.cancelDownload();
            currentDownloading = null;
        }
        if (downloadFile == currentPlaying) {
            reset();
            setCurrentPlaying(null, false);
        }
        downloadList.remove(downloadFile);
        revision++;
        lifecycleSupport.serializeDownloadQueue();
    }

    @Override
    public synchronized void delete(List<MusicDirectory.Entry> songs) {
        for (MusicDirectory.Entry song : songs) {
            forSong(song).delete();
        }
    }

    private synchronized void setCurrentPlaying(DownloadFile currentPlaying, boolean showNotification) {
        this.currentPlaying = currentPlaying;

        if (currentPlaying != null && showNotification) {
            Util.showPlayingNotification(this, handler, currentPlaying.getSong());
        } else {
            Util.hidePlayingNotification(this, handler);
        }
    }

    @Override
    public synchronized int getCurrentPlayingIndex() {
        return downloadList.indexOf(currentPlaying);
    }

    @Override
    public DownloadFile getCurrentPlaying() {
        return currentPlaying;
    }

    @Override
    public DownloadFile getCurrentDownloading() {
        return currentDownloading;
    }

    @Override
    public synchronized List<DownloadFile> getDownloads() {
        return new ArrayList<DownloadFile>(downloadList);
    }

    @Override
    public synchronized void play(DownloadFile file) {
        play(downloadList.indexOf(file));
    }

    @Override
    public synchronized void play(int index) {
        play(index, true);
    }

    synchronized void play(int index, boolean start) {
        if (index < 0 || index >= size()) {
            reset();
            setCurrentPlaying(null, false);
        } else {
            setCurrentPlaying(downloadList.get(index), start);
            checkDownloads();
            if (start) {
                bufferAndPlay();
            }
        }
    }

    @Override
    public synchronized void seekTo(int position) {
        try {
            mediaPlayer.seekTo(position);
        } catch (Exception x) {
            handleError(x);
        }
    }

    @Override
    public synchronized void previous() {
        int index = getCurrentPlayingIndex();
        if (index == -1) {
            return;
        }

        // Restart song if played more than five seconds.
        if (getPlayerPosition() > 5000 || index == 0) {
            play(index);
        } else {
            play(index - 1);
        }
    }

    @Override
    public synchronized void next() {
        int index = getCurrentPlayingIndex();
        if (index != -1) {
            play(index + 1);
        }
    }

    @Override
    public synchronized void pause() {
        try {
            mediaPlayer.pause();
            setPlayerState(PAUSED);
        } catch (Exception x) {
            handleError(x);
        }
    }

    @Override
    public synchronized void start() {
        try {
            mediaPlayer.start();
            setPlayerState(STARTED);
        } catch (Exception x) {
            handleError(x);
        }
    }

    @Override
    public synchronized void reset() {
        if (bufferTask != null) {
            bufferTask.cancel();
        }
        try {
            mediaPlayer.reset();
            setPlayerState(IDLE);
        } catch (Exception x) {
            handleError(x);
        }
    }

    @Override
    public synchronized int getPlayerPosition() {
        try {
            if (playerState == IDLE || playerState == DOWNLOADING || playerState == PREPARING) {
                return 0;
            }
//            Log.i(TAG, "Player pos: " + mediaPlayer.getCurrentPosition() + " of " + mediaPlayer.getDuration());
            return mediaPlayer.getCurrentPosition();
        } catch (Exception x) {
            handleError(x);
            return 0;
        }
    }

    @Override
    public synchronized int getPlayerDuration() {
        if (currentPlaying != null) {
            Integer duration = currentPlaying.getSong().getDuration();
            if (duration != null) {
                return duration * 1000;
            }
        }
        if (playerState != IDLE && playerState != DOWNLOADING && playerState != PlayerState.PREPARING) {
            try {
                return mediaPlayer.getDuration();
            } catch (Exception x) {
                handleError(x);
            }
        }
        return 0;
    }

    @Override
    public PlayerState getPlayerState() {
        return playerState;
    }

    private synchronized void setPlayerState(PlayerState playerState) {
        Log.i(TAG, this.playerState.name() + " -> " + playerState.name() + " (" + currentPlaying + ")");

        boolean show = this.playerState == PAUSED && playerState == PlayerState.STARTED;
        boolean hide = this.playerState == STARTED && playerState == PlayerState.PAUSED;
        this.playerState = playerState;
        if (show) {
            Util.showPlayingNotification(this, handler, currentPlaying.getSong());
        } else if (hide) {
            Util.hidePlayingNotification(this, handler);
        }
    }

    @Override
    public void setSuggestedPlaylistName(String name) {
        this.suggestedPlaylistName = name;
    }

    @Override
    public String getSuggestedPlaylistName() {
        return suggestedPlaylistName;
    }

    private synchronized void bufferAndPlay() {
        reset();

        bufferTask = new BufferTask(currentPlaying, 0);
        bufferTask.start();
    }

    private synchronized void doPlay(final DownloadFile downloadFile, int position) {
        try {
            final File file = downloadFile.isCompleteFileAvailable() ? downloadFile.getCompleteFile() : downloadFile.getPartialFile();
            downloadFile.updateModificationDate();
            mediaPlayer.setOnCompletionListener(null);
            mediaPlayer.reset();
            setPlayerState(IDLE);
            mediaPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC);
            mediaPlayer.setDataSource(file.getPath());
            setPlayerState(PREPARING);
            mediaPlayer.prepare();
            setPlayerState(PREPARED);

            mediaPlayer.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
                @Override
                public void onCompletion(MediaPlayer mediaPlayer) {

                    // Acquire a temporary wakelock, since when we return from
                    // this callback the MediaPlayer will release its wakelock
                    // and allow the device to go to sleep.
                    wakeLock.acquire(60000);

                    setPlayerState(COMPLETED);

                    // If COMPLETED and not playing partial file, we are *really" finished
                    // with the song and can move on to the next.
                    if (!file.equals(downloadFile.getPartialFile())) {
                        next();
                        return;
                    }

                    // If file is not completely downloaded, restart the playback from the current position.
                    int pos = mediaPlayer.getCurrentPosition();
                    synchronized (DownloadServiceImpl.this) {

                        // Work-around for apparent bug on certain phones: If close (less than ten seconds) to the end
                        // of the song, skip to the next rather than restarting it.
                        Integer duration = downloadFile.getSong().getDuration() == null ? null : downloadFile.getSong().getDuration() * 1000;
                        if (duration != null) {
                            if (Math.abs(duration - pos) < 10000) {
                                Log.i(TAG, "Skipping restart from " + pos  + " of " + duration);
                                next();
                                return;
                            }
                        }

                        Log.i(TAG, "Requesting restart from " + pos  + " of " + duration);
                        reset();
                        bufferTask = new BufferTask(downloadFile, pos);
                        bufferTask.start();
                    }
                }
            });

            if (position != 0) {
                Log.i(TAG, "Restarting player from position " + position);
                mediaPlayer.seekTo(position);
            }

            mediaPlayer.start();
            setPlayerState(STARTED);

        } catch (Exception x) {
            handleError(x);
        }
    }

    private void handleError(Exception x) {
        if (currentPlaying != null) {
            String msg = getResources().getString(R.string.download_play_error, currentPlaying.getSong().getTitle());
            Util.showErrorNotification(this, handler, msg, x);
            Log.e(TAG, msg, x);
        }
        mediaPlayer.reset();
        setPlayerState(IDLE);
    }

    protected synchronized void checkDownloads() {

        if (!Util.isNetworkConnected(this) || !Util.isExternalStoragePresent()) {
            return;
        }

        if (shufflePlay) {
            checkShufflePlay();
        }

        if (downloadList.isEmpty()) {
            return;
        }

        // Need to download current playing?
        if (currentPlaying != null &&
                currentPlaying != currentDownloading &&
                !currentPlaying.isCompleteFileAvailable()) {

            // Cancel current download, if necessary.
            if (currentDownloading != null) {
                currentDownloading.cancelDownload();
            }

            currentDownloading = currentPlaying;
            currentDownloading.download();
            cleanupCandidates.add(currentDownloading);
        }

        // Find a suitable target for download.
        else if (currentDownloading == null || currentDownloading.isWorkDone() || currentDownloading.isFailed()) {

            int n = size();
            if (n == 0) {
                return;
            }

            int preloaded = 0;

            int start = currentPlaying == null ? 0 : getCurrentPlayingIndex();
            int i = start;
            do {
                DownloadFile downloadFile = downloadList.get(i);
                if (!downloadFile.isWorkDone()) {
                    if (downloadFile.shouldSave() || preloaded < Util.getPreloadCount(this)) {
                        currentDownloading = downloadFile;
                        currentDownloading.download();
                        cleanupCandidates.add(currentDownloading);
                        break;
                    }
                } else if (currentPlaying != downloadFile) {
                    preloaded++;
                }

                i = (i + 1) % n;
            } while (i != start);
        }

        // Delete obsolete .partial and .complete files.
        cleanup();
    }

    private synchronized void checkShufflePlay() {

        final int listSize = 20;
        boolean wasEmpty = downloadList.isEmpty();

        // First, ensure that list is at least 20 songs long.
        int size = size();
        if (size < listSize) {
            for (MusicDirectory.Entry song : shufflePlayBuffer.get(listSize - size)) {
                DownloadFile downloadFile = new DownloadFile(this, song, false);
                downloadList.add(downloadFile);
                revision++;
            }
        }

        int currIndex = currentPlaying == null ? 0 : getCurrentPlayingIndex();

        // Only shift playlist if playing song #5 or later.
        if (currIndex > 4) {
            int songsToShift = currIndex - 2;
            for (MusicDirectory.Entry song : shufflePlayBuffer.get(songsToShift)) {
                downloadList.add(new DownloadFile(this, song, false));
                downloadList.get(0).cancelDownload();
                downloadList.remove(0);
                revision++;
            }
        }

        if (wasEmpty && !downloadList.isEmpty()) {
            play(0);
        }
    }

    public long getDownloadListUpdateRevision() {
        return revision;
    }

    private synchronized void cleanup() {
        Iterator<DownloadFile> iterator = cleanupCandidates.iterator();
        while (iterator.hasNext()) {
            DownloadFile downloadFile = iterator.next();
            if (downloadFile != currentPlaying && downloadFile != currentDownloading) {
                if (downloadFile.cleanup()) {
                    iterator.remove();
                }
            }
        }
    }

    private class BufferTask extends CancellableTask {

        private static final int BUFFER_LENGTH_SECONDS = 5;

        private final DownloadFile downloadFile;
        private final int position;
        private final long expectedFileSize;
        private final File partialFile;

        public BufferTask(DownloadFile downloadFile, int position) {
            this.downloadFile = downloadFile;
            this.position = position;
            partialFile = downloadFile.getPartialFile();

            // Calculate roughly how many bytes BUFFER_LENGTH_SECONDS corresponds to.
            Integer bitRate = downloadFile.getSong().getBitRate();
            if (bitRate == null) {
                bitRate = 160;
            }
            long byteCount = Math.max(100000, bitRate * 1024 / 8 * BUFFER_LENGTH_SECONDS);

            // Find out how large the file should grow before resuming playback.
            expectedFileSize = partialFile.length() + byteCount;
        }

        @Override
        public void execute() {
            setPlayerState(DOWNLOADING);

            while (!bufferComplete()) {
                Util.sleepQuietly(1000L);
                if (isCancelled()) {
                    return;
                }
            }
            doPlay(downloadFile, position);
        }

        private boolean bufferComplete() {
            boolean completeFileAvailable = downloadFile.isCompleteFileAvailable();
            long size = partialFile.length();

            Log.i(TAG, "Buffering " + partialFile + " (" + size + "/" + expectedFileSize + ", " + completeFileAvailable + ")");
            return completeFileAvailable || size >= expectedFileSize;
        }

        @Override
        public String toString() {
            return "BufferTask (" + downloadFile + ")";
        }
    }
}
