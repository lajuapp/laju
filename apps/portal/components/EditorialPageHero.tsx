'use client';

import type { ReactNode } from 'react';
import { CheckCircle2 } from 'lucide-react';
import { Reveal } from './landing/Reveal';

interface EditorialPageHeroProps {
  titleLine1: string;
  titleLine2: string;
  description: string;
  guarantees: string[];
  image: string;
  imageAlt: string;
  children: ReactNode;
}

export function EditorialPageHero({
  titleLine1,
  titleLine2,
  description,
  guarantees,
  image,
  imageAlt,
  children,
}: EditorialPageHeroProps) {
  return (
    <header className="mb-16 grid grid-cols-1 items-center gap-10 sm:mb-20 lg:grid-cols-12 lg:gap-14">
      <Reveal direction="left" className="space-y-5 text-left lg:col-span-7 lg:space-y-6">
        <h1 className="text-[2.65rem] font-black leading-[1.02] tracking-[-0.045em] text-slate-950 sm:text-5xl lg:text-6xl">
          {titleLine1}<br />
          <span className="text-[#0D382C]">{titleLine2}</span>
        </h1>

        <p className="max-w-2xl text-sm leading-7 text-slate-600 sm:text-base sm:leading-8 lg:text-lg">
          {description}
        </p>

        <ul className="grid grid-cols-1 gap-x-5 gap-y-3 pt-1 text-xs font-medium leading-relaxed text-slate-700 sm:grid-cols-2 sm:text-sm">
          {guarantees.map((item) => (
            <li key={item} className="flex items-start gap-2.5">
              <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-[#0D6B50]" />
              <span>{item}</span>
            </li>
          ))}
        </ul>

        <div className="flex flex-wrap items-center gap-3 pt-1 sm:gap-4">{children}</div>
      </Reveal>

      <Reveal direction="right" delay={100} className="lg:col-span-5">
        <figure className="landing-image-frame group relative aspect-[4/3] w-full overflow-hidden rounded-[1.75rem] border border-[#EAE8DE] bg-white shadow-[0_28px_70px_-42px_rgba(15,23,42,0.48)] sm:rounded-[2rem] lg:rounded-[2.25rem]">
          <img src={image} alt={imageAlt} className="h-full w-full object-cover" />
          <div aria-hidden="true" className="pointer-events-none absolute inset-0 ring-1 ring-inset ring-white/20" />
        </figure>
      </Reveal>
    </header>
  );
}
