import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import './globals.css';
import { Providers } from '@/components/providers';

export const metadata: Metadata = {
  title: 'Ritual News Terminal',
  description: 'Read-only Ritual Chain dashboard for on-chain crypto sentiment.',
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <body className="bg-paper font-mono text-ink">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
