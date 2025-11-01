import './SongList.css';

function SongList({ songs }) {
  return (
    <div className="song-list">
      {songs.map((song) => (
        <div key={song.id} className="song-item">
          <div className="song-info">
            <h3>{song.title}</h3>
            {song.release_date && (
              <span className="release-date">{song.release_date}</span>
            )}
          </div>
          <a
            href={song.url}
            target="_blank"
            rel="noopener noreferrer"
            className="view-link"
          >
            View Lyrics →
          </a>
        </div>
      ))}
    </div>
  );
}

export default SongList;