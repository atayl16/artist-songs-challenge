import { useState } from 'react';
import './ArtistSearch.css';

function ArtistSearch({ onSearch, disabled }) {
  const [input, setInput] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    if (input.trim()) {
      onSearch(input.trim());
    }
  };

  const handleClear = () => {
    setInput('');
  };

  return (
    <form onSubmit={handleSubmit} className="search-form">
      <div className="search-input-wrapper">
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Enter artist name (e.g., Pink Floyd)..."
          className="search-input"
          disabled={disabled}
          autoFocus
        />
        {input && !disabled && (
          <button
            type="button"
            onClick={handleClear}
            className="clear-button"
            aria-label="Clear search"
          >
            ✕
          </button>
        )}
      </div>
      <button 
        type="submit" 
        disabled={disabled || !input.trim()} 
        className="search-button"
      >
        Search
      </button>
    </form>
  );
}

export default ArtistSearch;