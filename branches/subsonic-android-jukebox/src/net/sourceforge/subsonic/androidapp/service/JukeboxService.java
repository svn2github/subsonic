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

import android.content.Context;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.ProgressBar;
import android.widget.Toast;
import net.sourceforge.subsonic.androidapp.R;
import net.sourceforge.subsonic.androidapp.domain.JukeboxStatus;
import net.sourceforge.subsonic.androidapp.domain.PlayerState;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

/**
 * @author Sindre Mehus
 * @version $Id$
 */
public class JukeboxService {

    private static final String TAG = JukeboxService.class.getSimpleName();
    private static final long STATUS_UPDATE_INTERVAL_SECONDS = 4L; // TODO

    private final TaskQueue tasks = new TaskQueue();
    private final DownloadServiceImpl downloadService;
    private final ScheduledExecutorService executorService = Executors.newSingleThreadScheduledExecutor();
    private final AtomicLong sequenceNumber = new AtomicLong();
    private ScheduledFuture<?> statusUpdateFuture;
    private AtomicLong timeOfLastUpdate = new AtomicLong();
    private JukeboxStatus jukeboxStatus;
    private float gain = 0.5f;
    private VolumeToast volumeToast;

    // TODO: Disable jukebox when offline.
    // TODO: Use different update interval when connected to wifi.
    // TODO: Create shutdown method?
    // TODO: Landscape mode
    // TODO: Shuffle play
    // TODO: Change gui for toggling?
    // TODO: Test shuffle.
    // TODO: Disable repeat.
    // TODO: Persist RC state.
    // TODO: Minimize status updates.
    // TODO: Stop status updates when disabling jukebox.
    // TODO: Widget broken?
    // TODO: Make sure position < duration.
    // TODO: Set initial playing state and position.
    // TODO: Handle incompatible server
    // TODO: Rename to "Remote volume"?

    public JukeboxService(DownloadServiceImpl downloadService) {
        this.downloadService = downloadService;
        new Thread() {
            @Override
            public void run() {
                processTasks();
            }
        }.start();
    }

    private synchronized void startStatusUpdate() {
        stopStatusUpdate();
        Runnable updateTask = new Runnable() {
            @Override
            public void run() {
                updateStatus();
            }
        };
        statusUpdateFuture = executorService.scheduleWithFixedDelay(updateTask, STATUS_UPDATE_INTERVAL_SECONDS,
                STATUS_UPDATE_INTERVAL_SECONDS, TimeUnit.SECONDS);
    }

    private synchronized void stopStatusUpdate() {
        if (statusUpdateFuture != null) {
            statusUpdateFuture.cancel(false);
            statusUpdateFuture = null;
        }
    }

    private void updateStatus() {
        try {
            long seqNo = sequenceNumber.get();
            JukeboxStatus status = getMusicService().getJukeboxStatus(downloadService, null);

            // Only update status if no other commands have been issued in the meantime.
            if (seqNo == sequenceNumber.get()) {
                onStatusUpdate(status);
            } else {
                Log.d(TAG, "Ignoring status update 1.");
            }
        } catch (Throwable x) {
            Log.e(TAG, "Failed to update jukebox status: " + x, x);
        }
    }

    private void onStatusUpdate(JukeboxStatus jukeboxStatus) {
        timeOfLastUpdate.set(System.currentTimeMillis());
        this.jukeboxStatus = jukeboxStatus;
        if (jukeboxStatus.getGain() != null) {
            gain = jukeboxStatus.getGain();
        }

        // Track change?
        Integer index = jukeboxStatus.getCurrentPlayingIndex();
        if (index != null && index != -1 && index != downloadService.getCurrentPlayingIndex()) {
            downloadService.setCurrentPlaying(index, true);
        }
    }

    private void processTasks() {
        while (true) {
            try {
                JukeboxTask task = tasks.take();

                long seqNo = sequenceNumber.get();
                JukeboxStatus status = task.execute();

                // Only update status if no other commands have been issued in the meantime.
                if (seqNo == sequenceNumber.get()) {
                    onStatusUpdate(status);
                } else {
                    Log.d(TAG, "Ignoring status update 2.");
                }
            } catch (Throwable x) {
                Log.e(TAG, "Failed to process jukebox task: " + x, x);
            }
        }
    }

    public void updatePlaylist() {
        tasks.remove(Skip.class);
        tasks.remove(Stop.class);
        tasks.remove(Start.class);

        List<String> ids = new ArrayList<String>();
        for (DownloadFile file : downloadService.getDownloads()) {
            ids.add(file.getSong().getId());
        }
        tasks.add(new SetPlaylist(ids));
    }

    public void skip(final int index, final int offsetSeconds) {
        tasks.remove(Skip.class);
        tasks.remove(Stop.class);
        tasks.remove(Start.class);

        startStatusUpdate();
        if (jukeboxStatus != null) {
            jukeboxStatus.setPositionSeconds(offsetSeconds);
        }
        tasks.add(new Skip(index, offsetSeconds));
        downloadService.setPlayerState(PlayerState.STARTED);
    }

    public void stop() {
        tasks.remove(Stop.class);
        tasks.remove(Start.class);

        stopStatusUpdate();
        tasks.add(new Stop());
    }

    public void start() {
        tasks.remove(Stop.class);
        tasks.remove(Start.class);

        startStatusUpdate();
        tasks.add(new Start());
    }

    public synchronized void adjustVolume(boolean up) {
        float delta = up ? 0.1f : -0.1f;
        gain += delta;
        gain = Math.max(gain, 0.0f);
        gain = Math.min(gain, 1.0f);

        tasks.remove(SetGain.class);
        tasks.add(new SetGain(gain));

        if (volumeToast == null) {
            volumeToast = new VolumeToast(downloadService);
        }
        volumeToast.setVolume(gain);
    }

    private MusicService getMusicService() {
        return MusicServiceFactory.getMusicService(downloadService);
    }

    public int getPositionSeconds() {
        if (jukeboxStatus == null || timeOfLastUpdate.get() == 0) {
            return 0;
        }

        if (jukeboxStatus.isPlaying()) {
            int secondsSinceLastUpdate = (int) ((System.currentTimeMillis() - timeOfLastUpdate.get()) / 1000L);
            return jukeboxStatus.getPositionSeconds() + secondsSinceLastUpdate;
        }

        return jukeboxStatus.getPositionSeconds();
    }

    public void setEnabled(boolean enabled) {
        if (enabled) {
            updatePlaylist();
        }
    }

    private static class TaskQueue {

        private final LinkedBlockingQueue<JukeboxTask> queue = new LinkedBlockingQueue<JukeboxTask>();

        void add(JukeboxTask jukeboxTask) {
            queue.add(jukeboxTask);
        }

        JukeboxTask take() throws InterruptedException {
            return queue.take();
        }

        void remove(Class<? extends JukeboxTask> clazz) {
            try {
                Iterator<JukeboxTask> iterator = queue.iterator();
                while (iterator.hasNext()) {
                    JukeboxTask task = iterator.next();
                    if (clazz.equals(task.getClass())) {
                        iterator.remove();
                    }
                }
            } catch (Throwable x) {
                Log.w(TAG, "Failed to clean-up task queue.", x);
            }
        }
    }

    private abstract class JukeboxTask {

        JukeboxTask() {
            sequenceNumber.incrementAndGet();
        }

        abstract JukeboxStatus execute() throws Exception;

        @Override
        public String toString() {
            return getClass().getSimpleName();
        }
    }

    private class SetPlaylist extends JukeboxTask {

        private final List<String> ids;

        SetPlaylist(List<String> ids) {
            this.ids = ids;
        }

        @Override
        JukeboxStatus execute() throws Exception {
            return getMusicService().updateJukeboxPlaylist(ids, downloadService, null);
        }
    }

    private class Skip extends JukeboxTask {
        private final int index;
        private final int offsetSeconds;

        Skip(int index, int offsetSeconds) {
            this.index = index;
            this.offsetSeconds = offsetSeconds;
        }

        @Override
        JukeboxStatus execute() throws Exception {
            return getMusicService().skipJukebox(index, offsetSeconds, downloadService, null);
        }
    }

    private class Stop extends JukeboxTask {
        @Override
        JukeboxStatus execute() throws Exception {
            return getMusicService().stopJukebox(downloadService, null);
        }
    }

    private class Start extends JukeboxTask {
        @Override
        JukeboxStatus execute() throws Exception {
            return getMusicService().startJukebox(downloadService, null);
        }
    }

    private class SetGain extends JukeboxTask {

        private final float gain;

        private SetGain(float gain) {
            this.gain = gain;
        }

        @Override
        JukeboxStatus execute() throws Exception {
            return getMusicService().setJukeboxGain(gain, downloadService, null);
        }
    }

    private static class VolumeToast extends Toast {

        private final ProgressBar progressBar;

        public VolumeToast(Context context) {
            super(context);
            setDuration(Toast.LENGTH_SHORT);
            LayoutInflater inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            View view = inflater.inflate(R.layout.jukebox_volume, null);
            progressBar = (ProgressBar) view.findViewById(R.id.jukebox_volume_progress_bar);

            setView(view);
            setGravity(Gravity.TOP, 0, 0);
        }

        public void setVolume(float volume) {
            progressBar.setProgress(Math.round(100 * volume));
            show();
        }
    }
}
