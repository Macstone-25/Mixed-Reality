import { X } from "lucide-react";
import Link from "next/link";

interface NavItem {
  label: string;
  href: string;
}

interface SidenavProps {
  isOpen: boolean;
  onToggle: () => void;
  navItems?: NavItem[];
}

const defaultNavItems: NavItem[] = [
  { label: "Dashboard", href: "/" },
  { label: "All Sessions", href: "/sessions" },
];

export function Sidenav({ isOpen, onToggle, navItems = defaultNavItems }: SidenavProps) {
  return (
    <>
      {/* Sidenav */}
      <nav
        className={`fixed left-0 top-0 h-screen w-64 shadow-lg transform transition-transform duration-300 ease-in-out z-40 ${
          isOpen ? "translate-x-0" : "-translate-x-full"
        }`}
        style={{ backgroundColor: '#7F5539' }}
      >
        <div className="flex flex-col h-full p-6" style={{ color: '#F5F1ED' }}>
          {/* Close button */}
          <button
            onClick={onToggle}
            className="self-end mb-8 p-2 rounded-lg transition-colors"
            style={{ color: '#F5F1ED', backgroundColor: 'rgba(245, 241, 237, 0.1)' }}
            onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.2)')}
            onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.1)')}
            aria-label="Close navigation"
          >
            <X size={24} />
          </button>

          {/* Navigation items */}
          <div className="space-y-2 flex-1">
            {navItems.map((item) => (
              <Link
                key={item.label}
                href={item.href}
                className="block px-4 py-2 rounded-lg transition-colors"
                style={{ color: '#F5F1ED' }}
                onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.15)')}
                onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
              >
                {item.label}
              </Link>
            ))}
          </div>

          {/* Footer */}
          <div className="border-t pt-4" style={{ borderColor: 'rgba(245, 241, 237, 0.2)' }}>
            <p className="text-sm" style={{ color: 'rgba(245, 241, 237, 0.6)' }}>Capstone © 2026</p>
          </div>
        </div>
      </nav>

      {/* Overlay when sidenav is open */}
      {isOpen && (
        <div
          className="fixed inset-0 z-30 transition-opacity"
          onClick={onToggle}
          aria-hidden="true"
        />
      )}
    </>
  );
}
