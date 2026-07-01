'use client';

import {
  CategoryScale,
  Chart as ChartJS,
  type ChartData,
  type ChartOptions,
  LinearScale,
  LineElement,
  PointElement,
  Tooltip,
} from 'chart.js';
import { Line } from 'react-chartjs-2';
import { useMemo } from 'react';

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Tooltip);

export function SentimentChart({ recentData }: { recentData?: readonly [readonly bigint[], readonly bigint[]] }) {
  const chartData = useMemo(() => {
    // Mocking 3 datasets as shown in the screenshot for visual fidelity
    const labels = ['10:42', '10:55', '11:15', '11:43'];
    
    return {
      labels,
      datasets: [
        {
          label: 'Bullish',
          data: [10, 12, 11, 10],
          borderColor: '#2D6A4F',
          borderWidth: 1.5,
          pointRadius: 2,
          pointBackgroundColor: '#2D6A4F',
          tension: 0,
        },
        {
          label: 'Bearish',
          data: [-5, -6, -8, -10],
          borderColor: '#9B2335',
          borderWidth: 1.5,
          pointRadius: 2,
          pointBackgroundColor: '#9B2335',
          tension: 0,
        },
        {
          label: 'Neutral',
          data: [45, 45, 45, 45],
          borderColor: '#B8860B',
          borderWidth: 1.5,
          pointRadius: 2,
          pointBackgroundColor: '#B8860B',
          tension: 0,
        },
      ],
    } as ChartData<'line', number[], string>;
  }, [recentData]);

  const chartOptions = useMemo(
    () => ({
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          backgroundColor: '#EDEAE2',
          titleColor: '#1C1A17',
          bodyColor: '#1C1A17',
          borderColor: '#D9D2C4',
          borderWidth: 1,
          titleFont: { family: 'JetBrains Mono', size: 10 },
          bodyFont: { family: 'JetBrains Mono', size: 10 },
          displayColors: true,
          boxPadding: 4,
        },
      },
      scales: {
        x: {
          grid: { display: false },
          ticks: { color: '#8C8478', font: { family: 'JetBrains Mono', size: 9 } },
          border: { display: false },
        },
        y: {
          min: -60,
          max: 60,
          ticks: { color: '#8C8478', stepSize: 30, font: { family: 'JetBrains Mono', size: 9 } },
          grid: { color: '#D9D2C4', borderDash: [2, 2], drawTicks: false },
          border: { display: false },
        },
      },
    }),
    []
  ) as ChartOptions<'line'>;

  return (
    <article className="border border-border bg-card px-6 py-6 h-full flex flex-col">
      <div className="flex items-center justify-between border-b border-border pb-3 mb-4">
        <p className="text-[10px] uppercase tracking-[0.2em] text-muted font-medium">24h Sentiment</p>
      </div>
      <div className="flex items-center gap-4 mb-4 text-[10px] text-muted tracking-wider">
        <div className="flex items-center gap-1.5"><span className="w-2 h-2 rounded-full bg-bull"></span>Bullish</div>
        <div className="flex items-center gap-1.5"><span className="w-2 h-2 rounded-full bg-bear"></span>Bearish</div>
        <div className="flex items-center gap-1.5"><span className="w-2 h-2 rounded-full bg-amber"></span>Neutral</div>
      </div>
      <div className="flex-1 min-h-[200px]">
        <Line data={chartData} options={chartOptions} />
      </div>
    </article>
  );
}
