import { useState, useRef, useEffect } from 'react';
import ArtistSearch from './components/ArtistSearch';
import SongList from './components/SongList';
import logo from './logo.png';
import './App.css';

const API_BASE = process.env.REACT_APP_API_URL || 'http://localhost:3001';

function App() {
  const [songs, setSongs] = useState([]);
  const [pagination, setPagination] = useState(null);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState(null);
  const [currentArtist, setCurrentArtist] = useState('');
  const abortControllerRef = useRef(null);

  const fetchSongs = async (artistName, page = 1, append = false) => {
    // Cancel previous request if starting a new search (not appending)
    if (!append && abortControllerRef.current) {
      abortControllerRef.current.abort();
    }

    // Create new abort controller for this request
    const abortController = new AbortController();
    if (!append) {
      abortControllerRef.current = abortController;
    }

    if (page === 1) {
      setLoading(true);
      setSongs([]);
    } else {
      setLoadingMore(true);
    }

    setError(null);

    try {
      const response = await fetch(
        `${API_BASE}/api/v1/artists/${encodeURIComponent(artistName)}/songs?page=${page}&per_page=50`,
        { signal: abortController.signal }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Something went wrong');
      }

      if (append) {
        setSongs(prev => [...prev, ...data.songs]);
      } else {
        setSongs(data.songs);
        setCurrentArtist(artistName);
      }

      setPagination(data.pagination);
    } catch (err) {
      // Don't show error if request was cancelled
      if (err.name === 'AbortError') {
        console.log('Request cancelled');
        return;
      }
      setError(err.message);
      if (!append) {
        setSongs([]);
        setPagination(null);
      }
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (abortControllerRef.current) {
        abortControllerRef.current.abort();
      }
    };
  }, []);

  const handleSearch = (artistName) => {
    fetchSongs(artistName, 1, false);
  };

  const handleLoadMore = () => {
    if (pagination?.has_next) {
      fetchSongs(currentArtist, pagination.page + 1, true);
    }
  };

  return (
    <div className="App">
      <header className="app-header">
        <img src={logo} alt="Logo" className="app-logo" />
        <h1>Artist Song Search</h1>
        <p>Search for any artist to discover their songs</p>
      </header>
      
      <main className="app-main">
        <ArtistSearch onSearch={handleSearch} disabled={loading} />
        
        {loading && (
          <div className="loading">
            <div className="spinner"></div>
            <p>Searching for songs...</p>
          </div>
        )}
        
        {error && (
          <div className="error">
            <p>{error}</p>
          </div>
        )}
        
        {songs.length > 0 && (
          <>
            <div className="results-header">
              <h2>{currentArtist}</h2>
            </div>
            
            <SongList songs={songs} />
            
            {pagination?.has_next && (
              <button 
                onClick={handleLoadMore} 
                disabled={loadingMore}
                className="load-more-btn"
              >
                {loadingMore ? 'Loading...' : 'Load More Songs'}
              </button>
            )}
            
            {!pagination?.has_next && songs.length > 0 && (
              <p className="end-message">
                That's all the songs! 🎉
              </p>
            )}
          </>
        )}
        
        {!loading && !error && songs.length === 0 && !currentArtist && (
          <div className="empty-state">
            <p>Enter an artist name above to get started</p>
          </div>
        )}
      </main>
    </div>
  );
}

export default App;