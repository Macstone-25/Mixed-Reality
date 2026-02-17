import { ReactNode } from "react";

export interface MetricItem {
  label: string;
  value: string | number;
  icon?: ReactNode;
  color?: string;
  badge?: boolean;
}

export interface Section {
  title?: string;
  items: MetricItem[] | ReactNode;
}

export interface SessionHealthCardProps {
  title: string;
  status?: {
    label: string;
    isActive: boolean;
  };
  topLeftContent?: ReactNode;
  topRightContent?: ReactNode;
  bottomSections?: Section[];
  backgroundColor?: string;
}

export function SessionHealthCard({
  title,
  status,
  topLeftContent,
  topRightContent,
  bottomSections = [],
  backgroundColor = '#9C6644',
}: SessionHealthCardProps) {
  return (
    <div className="rounded-xl p-8 shadow-md flex flex-col h-full" style={{ backgroundColor }}>
      {/* Header with Title and Status */}
      <div className="flex justify-between items-start mb-6">
        <h2 className="text-lg font-semibold" style={{ color: '#F5F1ED' }}>
          {title}
        </h2>
        {status && (
          <div
            className="flex items-center gap-2 px-3 py-1 rounded-full animate-pulse"
            style={{
              backgroundColor: status.isActive ? 'rgba(230, 204, 178, 0.2)' : 'rgba(255, 181, 160, 0.2)',
              color: status.isActive ? '#E6CCB2' : '#FFB5A0',
            }}
          >
            {status.label}
          </div>
        )}
      </div>

      {/* Top Section - Responsive Grid */}
      {(topLeftContent || topRightContent) && (
        <div className="grid md:grid-cols-2 grid-cols-1 gap-6 mb-6 md:mb-8">
          {topLeftContent && <div>{topLeftContent}</div>}
          {topRightContent && <div>{topRightContent}</div>}
        </div>
      )}

      {/* Bottom Sections */}
      {bottomSections.length > 0 && (
        <div className="space-y-4 mt-6 pt-4" style={{ borderTop: '1px solid rgba(245, 241, 237, 0.2)' }}>
          {bottomSections.map((section, index) => (
            <div key={index}>
              {section.title && (
                <p
                  className="text-xs font-semibold mb-3 uppercase tracking-wider"
                  style={{ color: 'rgba(245, 241, 237, 0.5)' }}
                >
                  {section.title}
                </p>
              )}
              <div className="space-y-3">
                {Array.isArray(section.items) ? (
                  section.items.map((item: MetricItem, itemIndex: number) => (
                    <div key={itemIndex} className="flex justify-between items-center">
                      <div className="flex items-center gap-2">
                        {item.icon && <div style={{ color: item.color || '#E6CCB2' }}>{item.icon}</div>}
                        <span className="text-xs" style={{ color: 'rgba(245, 241, 237, 0.8)' }}>
                          {item.label}
                        </span>
                      </div>
                      {item.badge ? (
                        <span
                          className="text-sm font-bold px-2.5 py-1 rounded-full"
                          style={{
                            backgroundColor: `${item.color}33`,
                            color: item.color || '#FFB5A0',
                          }}
                        >
                          {item.value}
                        </span>
                      ) : (
                        <span className="text-sm font-bold" style={{ color: '#F5F1ED' }}>
                          {item.value}
                        </span>
                      )}
                    </div>
                  ))
                ) : (
                  section.items
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
