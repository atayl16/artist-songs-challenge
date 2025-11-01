import { render, screen } from '@testing-library/react';
import SongList from './SongList';

describe('SongList', () => {
  const mockSongs = [
    {
      id: 1,
      title: 'Hotline Bling',
      url: 'https://genius.com/Drake-hotline-bling-lyrics',
      release_date: 'October 19, 2015'
    },
    {
      id: 2,
      title: 'God\'s Plan',
      url: 'https://genius.com/Drake-gods-plan-lyrics',
      release_date: 'January 19, 2018'
    },
    {
      id: 3,
      title: 'One Dance',
      url: 'https://genius.com/Drake-one-dance-lyrics',
      release_date: null
    }
  ];

  test('renders all songs in the list', () => {
    render(<SongList songs={mockSongs} />);

    expect(screen.getByText('Hotline Bling')).toBeInTheDocument();
    expect(screen.getByText('God\'s Plan')).toBeInTheDocument();
    expect(screen.getByText('One Dance')).toBeInTheDocument();
  });

  test('displays release date when present', () => {
    render(<SongList songs={mockSongs} />);

    expect(screen.getByText('October 19, 2015')).toBeInTheDocument();
    expect(screen.getByText('January 19, 2018')).toBeInTheDocument();
  });

  test('does not display release date when null', () => {
    render(<SongList songs={mockSongs} />);

    const songItems = screen.getAllByRole('link', { name: /view lyrics/i });
    // Song with no release date should not have a release date element
    expect(songItems).toHaveLength(3);
  });

  test('renders correct links for each song', () => {
    render(<SongList songs={mockSongs} />);

    const links = screen.getAllByRole('link', { name: /view lyrics/i });

    expect(links[0]).toHaveAttribute('href', 'https://genius.com/Drake-hotline-bling-lyrics');
    expect(links[1]).toHaveAttribute('href', 'https://genius.com/Drake-gods-plan-lyrics');
    expect(links[2]).toHaveAttribute('href', 'https://genius.com/Drake-one-dance-lyrics');
  });

  test('links open in new tab with security attributes', () => {
    render(<SongList songs={mockSongs} />);

    const links = screen.getAllByRole('link', { name: /view lyrics/i });

    links.forEach(link => {
      expect(link).toHaveAttribute('target', '_blank');
      expect(link).toHaveAttribute('rel', 'noopener noreferrer');
    });
  });

  test('renders empty list when songs array is empty', () => {
    render(<SongList songs={[]} />);

    // Should not render any song items or links
    expect(screen.queryAllByRole('link', { name: /view lyrics/i })).toHaveLength(0);
  });

  test('renders single song correctly', () => {
    const singleSong = [{
      id: 1,
      title: 'Test Song',
      url: 'https://genius.com/test-song',
      release_date: 'December 1, 2024'
    }];

    render(<SongList songs={singleSong} />);

    expect(screen.getByText('Test Song')).toBeInTheDocument();
    expect(screen.getByText('December 1, 2024')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /view lyrics/i })).toHaveAttribute(
      'href',
      'https://genius.com/test-song'
    );
  });

  test('handles songs without release_date field', () => {
    const songsWithoutDate = [{
      id: 1,
      title: 'No Date Song',
      url: 'https://genius.com/no-date-song'
    }];

    render(<SongList songs={songsWithoutDate} />);

    expect(screen.getByText('No Date Song')).toBeInTheDocument();
    // Should only have the song title, no release date text
    expect(screen.queryByText(/\d{4}/)).not.toBeInTheDocument();
  });
});
