package net.sourceforge.subsonic.dao;

import net.sourceforge.subsonic.domain.PodcastChannel;
import net.sourceforge.subsonic.domain.PodcastEpisode;
import net.sourceforge.subsonic.domain.PodcastStatus;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.ParameterizedRowMapper;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;

/**
 * Provides database services for Podcast channels and episodes.
 *
 * @author Sindre Mehus
 */
@SuppressWarnings({"unchecked"})
public class PodcastDao extends AbstractDao {

    private static final String CHANNEL_COLUMNS = "id, url, title, description, status, error_message";
    private static final String EPISODE_COLUMNS = "id, channel_id, url, path, title, description, publish_date, " +
                                                  "duration, bytes_total, bytes_downloaded, status, error_message";

    private PodcastChannelRowMapper channelRowMapper = new PodcastChannelRowMapper();
    private PodcastEpisodeRowMapper episodeRowMapper = new PodcastEpisodeRowMapper();

    /**
     * Creates a new Podcast channel.
     *
     * @param channel The Podcast channel to create.
     * @return The ID of the newly created channel.
     */
    public synchronized int createChannel(PodcastChannel channel) {
        String sql = "insert into podcast_channel (" + CHANNEL_COLUMNS + ") values (" + questionMarks(CHANNEL_COLUMNS) + ")";
        getJdbcTemplate().update(sql, new Object[]{null, channel.getUrl(), channel.getTitle(), channel.getDescription(),
                                                   channel.getStatus().name(), channel.getErrorMessage()});

        return getJdbcTemplate().queryForInt("select max(id) from podcast_channel");
    }

    /**
     * Returns all Podcast channels.
     *
     * @return Possibly empty array of all Podcast channels.
     */
    public PodcastChannel[] getAllChannels() {
        String sql = "select " + CHANNEL_COLUMNS + " from podcast_channel";
        return (PodcastChannel[]) getJdbcTemplate().query(sql, channelRowMapper).toArray(new PodcastChannel[0]);
    }

    /**
     * Updates the given Podcast channel.
     *
     * @param channel The Podcast channel to update.
     */
    public void updateChannel(PodcastChannel channel) {
        String sql = "update podcast_channel set url=?, title=?, description=?, status=?, error_message=? where id=?";
        getJdbcTemplate().update(sql, new Object[]{channel.getUrl(), channel.getTitle(), channel.getDescription(),
                                                   channel.getStatus().name(), channel.getErrorMessage(), channel.getId()});
    }

    /**
     * Deletes the Podcast channel with the given ID.
     *
     * @param id The Podcast channel ID.
     */
    public void deleteChannel(int id) {
        String sql = "delete from podcast_channel where id=?";
        getJdbcTemplate().update(sql, new Object[]{id});
    }

    /**
     * Creates a new Podcast episode.
     *
     * @param episode The Podcast episode to create.
     */
    public void createEpisode(PodcastEpisode episode) {
        String sql = "insert into podcast_episode (" + EPISODE_COLUMNS + ") values (" + questionMarks(EPISODE_COLUMNS) + ")";
        getJdbcTemplate().update(sql, new Object[]{null, episode.getChannelId(), episode.getUrl(), episode.getPath(),
                                                   episode.getTitle(), episode.getDescription(), episode.getPublishDate(),
                                                   episode.getDuration(), episode.getBytesTotal(), episode.getBytesDownloaded(),
                                                   episode.getStatus().name(), episode.getErrorMessage()});
    }

    /**
     * Returns all Podcast episodes for a given channel.
     *
     * @return Possibly empty array of all Podcast episodes for the given channel, sorted in
     *         reverse chronological order (newest episode first).
     */
    public PodcastEpisode[] getEpisodes(int channelId) {
        String sql = "select " + EPISODE_COLUMNS + " from podcast_episode where channel_id=" + channelId + " order by publish_date desc";
        return (PodcastEpisode[]) getJdbcTemplate().query(sql, episodeRowMapper).toArray(new PodcastEpisode[0]);
    }

    /**
     * Returns the Podcast episode with the given ID.
     *
     * @param episodeId The Podcast episode ID.
     * @return The episode or <code>null</code> if not found.
     */
    public PodcastEpisode getEpisode(int episodeId) {
        String sql = "select " + EPISODE_COLUMNS + " from podcast_episode where id=" + episodeId;
        List<?> result = getJdbcTemplate().query(sql, episodeRowMapper);
        return (PodcastEpisode) (result.isEmpty() ? null : result.get(0));
    }

    /**
     * Updates the given Podcast episode.
     *
     * @param episode The Podcast episode to update.
     * @return The number of episodes updated (zero or one).
     */
    public int updateEpisode(PodcastEpisode episode) {
        String sql = "update podcast_episode set url=?, path=?, title=?, description=?, publish_date=?, duration=?, " +
                     "bytes_total=?, bytes_downloaded=?, status=?, error_message=? where id=?";
        return getJdbcTemplate().update(sql, new Object[]{episode.getUrl(), episode.getPath(), episode.getTitle(),
                                                          episode.getDescription(), episode.getPublishDate(), episode.getDuration(),
                                                          episode.getBytesTotal(), episode.getBytesDownloaded(), episode.getStatus().name(),
                                                          episode.getErrorMessage(), episode.getId()});
    }

    /**
     * Deletes the Podcast episode with the given ID.
     *
     * @param id The Podcast episode ID.
     */
    public void deleteEpisode(int id) {
        String sql = "delete from podcast_episode where id=?";
        getJdbcTemplate().update(sql, new Object[]{id});
    }

    private static class PodcastChannelRowMapper implements RowMapper {
        public Object mapRow(ResultSet rs, int rowNum) throws SQLException {
            return new PodcastChannel(rs.getInt(1), rs.getString(2), rs.getString(3), rs.getString(4),
                                      PodcastStatus.valueOf(rs.getString(5)), rs.getString(6));
        }
    }

    private static class PodcastEpisodeRowMapper implements ParameterizedRowMapper<PodcastEpisode> {
        public PodcastEpisode mapRow(ResultSet rs, int rowNum) throws SQLException {
            return new PodcastEpisode(rs.getInt(1), rs.getInt(2), rs.getString(3), rs.getString(4), rs.getString(5),
                                      rs.getString(6), rs.getTimestamp(7), rs.getString(8), (Long) rs.getObject(9),
                                      (Long) rs.getObject(10), PodcastStatus.valueOf(rs.getString(11)), rs.getString(12));
        }
    }
}
