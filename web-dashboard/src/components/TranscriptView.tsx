import { Search } from 'lucide-react';
import { useState, useMemo } from 'react';

interface TranscriptViewProps {
  transcript: string[];
}

export function TranscriptView({ transcript }: TranscriptViewProps) {
  const [searchQuery, setSearchQuery] = useState('');

  const highlighted = useMemo(() => {
    if (!searchQuery) return transcript;

    return transcript.map(line => {
      const regex = new RegExp(`(${searchQuery})`, 'gi');
      return line.replace(regex, (match) => `__HIGHLIGHT_START__${match}__HIGHLIGHT_END__`);
    });
  }, [transcript, searchQuery]);

  return (
    <div className="bg-white rounded-xl shadow-md overflow-hidden">
      <div className="px-6 py-4" style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}>
        <h3 className="text-lg font-semibold">Transcript</h3>
      </div>

      {/* Search Bar */}
      {transcript.length > 0 && (
        <div className="px-6 py-4 border-b" style={{ borderColor: '#E6CCB2' }}>
          <div className="relative">
            <Search size={16} className="absolute left-3 top-3" style={{ color: '#9C6644' }} />
            <input
              type="text"
              placeholder="Search within transcript..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-2 rounded-lg border transition-colors"
              style={{
                borderColor: '#E6CCB2',
                backgroundColor: '#ffffff',
              }}
            />
          </div>
        </div>
      )}

      {/* Transcript Content */}
      <div className="px-6 py-4" style={{ backgroundColor: '#FAFAF8', minHeight: '300px' }}>
        {transcript.length > 0 ? (
          <div className="space-y-3">
            {highlighted.map((line, index) => {
              const parts = line.split(/(__HIGHLIGHT_START__|__HIGHLIGHT_END__)/);
              return (
                <p key={index} className="text-sm leading-relaxed" style={{ color: '#2D2D2D' }}>
                  {parts.map((part, i) => {
                    if (part === '__HIGHLIGHT_START__') return null;
                    if (part === '__HIGHLIGHT_END__') return null;
                    const isHighlight = i > 0 && parts[i - 1] === '__HIGHLIGHT_START__';
                    return (
                      <span
                        key={i}
                        style={{
                          backgroundColor: isHighlight ? '#FFE6B6' : 'transparent',
                          fontWeight: isHighlight ? 'bold' : 'normal',
                        }}
                      >
                        {part}
                      </span>
                    );
                  })}
                </p>
              );
            })}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center h-full" style={{ color: 'rgba(45, 45, 45, 0.5)' }}>
            <p className="text-sm">No transcript available</p>
          </div>
        )}
      </div>
    </div>
  );
}
