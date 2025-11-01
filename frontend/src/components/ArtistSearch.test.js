import { render, screen, fireEvent } from '@testing-library/react';
import ArtistSearch from './ArtistSearch';

describe('ArtistSearch', () => {
  test('calls onSearch with trimmed input when form is submitted', () => {
    const mockOnSearch = jest.fn();
    render(<ArtistSearch onSearch={mockOnSearch} disabled={false} />);

    const input = screen.getByPlaceholderText(/enter artist name/i);
    const button = screen.getByRole('button', { name: /search/i });

    fireEvent.change(input, { target: { value: '  Drake  ' } });
    fireEvent.click(button);

    expect(mockOnSearch).toHaveBeenCalledWith('Drake');
    expect(mockOnSearch).toHaveBeenCalledTimes(1);
  });

  test('calls onSearch when button is clicked with valid input', () => {
    const mockOnSearch = jest.fn();
    render(<ArtistSearch onSearch={mockOnSearch} disabled={false} />);

    const input = screen.getByPlaceholderText(/enter artist name/i);
    const button = screen.getByRole('button', { name: /search/i });

    fireEvent.change(input, { target: { value: 'Pink Floyd' } });
    fireEvent.click(button);

    expect(mockOnSearch).toHaveBeenCalledWith('Pink Floyd');
  });

  test('disables button when input is empty', () => {
    const mockOnSearch = jest.fn();
    render(<ArtistSearch onSearch={mockOnSearch} disabled={false} />);

    const button = screen.getByRole('button', { name: /search/i });
    expect(button).toBeDisabled();
  });

  test('disables button when input contains only whitespace', () => {
    const mockOnSearch = jest.fn();
    render(<ArtistSearch onSearch={mockOnSearch} disabled={false} />);

    const input = screen.getByPlaceholderText(/enter artist name/i);
    const button = screen.getByRole('button', { name: /search/i });

    fireEvent.change(input, { target: { value: '   ' } });
    expect(button).toBeDisabled();
  });

  test('enables button when input has valid text', () => {
    const mockOnSearch = jest.fn();
    render(<ArtistSearch onSearch={mockOnSearch} disabled={false} />);

    const input = screen.getByPlaceholderText(/enter artist name/i);
    const button = screen.getByRole('button', { name: /search/i });

    fireEvent.change(input, { target: { value: 'Drake' } });
    expect(button).not.toBeDisabled();
  });

  test('disables input and button when disabled prop is true', () => {
    const mockOnSearch = jest.fn();
    render(<ArtistSearch onSearch={mockOnSearch} disabled={true} />);

    const input = screen.getByPlaceholderText(/enter artist name/i);
    const button = screen.getByRole('button', { name: /search/i });

    expect(input).toBeDisabled();
    expect(button).toBeDisabled();
  });

  test('does not call onSearch when input is empty or whitespace-only', () => {
    const mockOnSearch = jest.fn();
    render(<ArtistSearch onSearch={mockOnSearch} disabled={false} />);

    const button = screen.getByRole('button', { name: /search/i });
    const input = screen.getByPlaceholderText(/enter artist name/i);

    // Button is disabled with empty input, so can't be clicked
    expect(button).toBeDisabled();

    // Try with whitespace-only input
    fireEvent.change(input, { target: { value: '   ' } });
    // Button should still be disabled
    expect(button).toBeDisabled();
    expect(mockOnSearch).not.toHaveBeenCalled();
  });

  test('updates input value as user types', () => {
    const mockOnSearch = jest.fn();
    render(<ArtistSearch onSearch={mockOnSearch} disabled={false} />);

    const input = screen.getByPlaceholderText(/enter artist name/i);

    fireEvent.change(input, { target: { value: 'Dr' } });
    expect(input.value).toBe('Dr');

    fireEvent.change(input, { target: { value: 'Drake' } });
    expect(input.value).toBe('Drake');
  });
});
