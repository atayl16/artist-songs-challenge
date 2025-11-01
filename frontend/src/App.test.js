import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import App from './App';

// Mock fetch globally
global.fetch = jest.fn();

describe('App', () => {
  beforeEach(() => {
    fetch.mockClear();
  });

  test('renders app header and search form', () => {
    render(<App />);

    expect(screen.getByText('Artist Song Search')).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/enter artist name/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Search' })).toBeInTheDocument();
  });

  test('displays empty state initially', () => {
    render(<App />);

    expect(screen.getByText(/enter an artist name above to get started/i)).toBeInTheDocument();
  });

  test('displays songs when search succeeds', async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        artist: { name: 'Drake', id: 1 },
        songs: [
          { id: 1, title: 'Hotline Bling', url: 'https://genius.com/1', release_date: 'October 19, 2015' },
          { id: 2, title: 'God\'s Plan', url: 'https://genius.com/2', release_date: 'January 19, 2018' }
        ],
        pagination: { page: 1, per_page: 50, has_next: false },
        meta: { fetched_at: new Date(), cached: false }
      })
    });

    render(<App />);

    const input = screen.getByPlaceholderText(/enter artist name/i);
    const button = screen.getByRole('button', { name: 'Search' });

    fireEvent.change(input, { target: { value: 'Drake' } });
    fireEvent.click(button);

    // Should show loading state
    expect(screen.getByText(/searching for songs/i)).toBeInTheDocument();

    // Wait for songs to appear
    await waitFor(() => {
      expect(screen.getByText('Hotline Bling')).toBeInTheDocument();
    });

    expect(screen.getByText('God\'s Plan')).toBeInTheDocument();
    expect(screen.getByText('Drake')).toBeInTheDocument();
    expect(screen.getByText(/that's all the songs/i)).toBeInTheDocument();
  });

  test('displays error message when search fails', async () => {
    fetch.mockResolvedValueOnce({
      ok: false,
      json: async () => ({
        error: 'Artist not found'
      })
    });

    render(<App />);

    const input = screen.getByPlaceholderText(/enter artist name/i);
    const button = screen.getByRole('button', { name: 'Search' });

    fireEvent.change(input, { target: { value: 'NonexistentArtist' } });
    fireEvent.click(button);

    await waitFor(() => {
      expect(screen.getByText(/artist not found/i)).toBeInTheDocument();
    });

    // Should not display songs
    expect(screen.queryByRole('link', { name: /view lyrics/i })).not.toBeInTheDocument();
  });

  test('loads more songs when Load More button is clicked', async () => {
    // First page response
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        artist: { name: 'Drake', id: 1 },
        songs: [
          { id: 1, title: 'Song 1', url: 'https://genius.com/1', release_date: null }
        ],
        pagination: { page: 1, per_page: 50, has_next: true },
        meta: { fetched_at: new Date(), cached: false }
      })
    });

    render(<App />);

    const input = screen.getByPlaceholderText(/enter artist name/i);
    fireEvent.change(input, { target: { value: 'Drake' } });
    fireEvent.click(screen.getByRole('button', { name: 'Search' }));

    await waitFor(() => {
      expect(screen.getByText('Song 1')).toBeInTheDocument();
    });

    // Mock second page response
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        artist: { name: 'Drake', id: 1 },
        songs: [
          { id: 2, title: 'Song 2', url: 'https://genius.com/2', release_date: null }
        ],
        pagination: { page: 2, per_page: 50, has_next: false },
        meta: { fetched_at: new Date(), cached: false }
      })
    });

    const loadMoreButton = screen.getByRole('button', { name: /load more songs/i });
    fireEvent.click(loadMoreButton);

    await waitFor(() => {
      expect(screen.getByText('Song 2')).toBeInTheDocument();
    });

    // Both songs should be present
    expect(screen.getByText('Song 1')).toBeInTheDocument();
    expect(screen.getByText('Song 2')).toBeInTheDocument();

    // Load More button should disappear
    expect(screen.queryByRole('button', { name: /load more songs/i })).not.toBeInTheDocument();
    expect(screen.getByText(/that's all the songs/i)).toBeInTheDocument();
  });

  test('clears previous results when new search is performed', async () => {
    // First search
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        artist: { name: 'Drake', id: 1 },
        songs: [
          { id: 1, title: 'Drake Song', url: 'https://genius.com/1', release_date: null }
        ],
        pagination: { page: 1, per_page: 50, has_next: false },
        meta: { fetched_at: new Date(), cached: false }
      })
    });

    render(<App />);

    const input = screen.getByPlaceholderText(/enter artist name/i);
    fireEvent.change(input, { target: { value: 'Drake' } });
    fireEvent.click(screen.getByRole('button', { name: 'Search' }));

    await waitFor(() => {
      expect(screen.getByText('Drake Song')).toBeInTheDocument();
    });

    // Second search
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        artist: { name: 'Kendrick Lamar', id: 2 },
        songs: [
          { id: 2, title: 'Kendrick Song', url: 'https://genius.com/2', release_date: null }
        ],
        pagination: { page: 1, per_page: 50, has_next: false },
        meta: { fetched_at: new Date(), cached: false }
      })
    });

    fireEvent.change(input, { target: { value: 'Kendrick Lamar' } });
    fireEvent.click(screen.getByRole('button', { name: 'Search' }));

    await waitFor(() => {
      expect(screen.getByText('Kendrick Song')).toBeInTheDocument();
    });

    // Previous results should be cleared
    expect(screen.queryByText('Drake Song')).not.toBeInTheDocument();
    expect(screen.getByText('Kendrick Lamar')).toBeInTheDocument();
  });

  test('disables search during loading', async () => {
    fetch.mockImplementationOnce(() =>
      new Promise(resolve => setTimeout(() => resolve({
        ok: true,
        json: async () => ({
          artist: { name: 'Drake', id: 1 },
          songs: [{ id: 1, title: 'Song', url: 'https://genius.com/1', release_date: null }],
          pagination: { page: 1, per_page: 50, has_next: false },
          meta: { fetched_at: new Date(), cached: false }
        })
      }), 100))
    );

    render(<App />);

    const input = screen.getByPlaceholderText(/enter artist name/i);
    const button = screen.getByRole('button', { name: 'Search' });

    fireEvent.change(input, { target: { value: 'Drake' } });
    fireEvent.click(button);

    // Input and button should be disabled during loading
    expect(input).toBeDisabled();
    expect(button).toBeDisabled();

    await waitFor(() => {
      expect(screen.getByText('Song')).toBeInTheDocument();
    });

    // Should be enabled again after loading
    expect(input).not.toBeDisabled();
  });

  test('passes AbortSignal to fetch requests', async () => {
    // Verify that AbortController signal is properly passed to fetch
    let capturedSignal;

    fetch.mockImplementationOnce((url, options) => {
      capturedSignal = options.signal;
      return Promise.resolve({
        ok: true,
        json: async () => ({
          artist: { name: 'Drake', id: 1 },
          songs: [{ id: 1, title: 'Hotline Bling', url: 'https://genius.com/1', release_date: null }],
          pagination: { page: 1, per_page: 50, has_next: false },
          meta: { fetched_at: new Date(), cached: false }
        })
      });
    });

    render(<App />);

    const input = screen.getByPlaceholderText(/enter artist name/i);
    const button = screen.getByRole('button', { name: 'Search' });

    fireEvent.change(input, { target: { value: 'Drake' } });
    fireEvent.click(button);

    await waitFor(() => {
      expect(screen.getByText('Hotline Bling')).toBeInTheDocument();
    });

    // Verify signal was passed to fetch
    expect(capturedSignal).toBeInstanceOf(AbortSignal);
    expect(capturedSignal).toBeDefined();
  });

  test('handles network errors gracefully', async () => {
    fetch.mockRejectedValueOnce(new Error('Network error'));

    render(<App />);

    const input = screen.getByPlaceholderText(/enter artist name/i);
    const button = screen.getByRole('button', { name: 'Search' });

    fireEvent.change(input, { target: { value: 'Drake' } });
    fireEvent.click(button);

    await waitFor(() => {
      expect(screen.getByText(/network error/i)).toBeInTheDocument();
    });
  });
});
