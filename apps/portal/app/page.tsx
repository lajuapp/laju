import { HeroSection } from '@/components/landing/HeroSection';
import { FeaturesSection } from '@/components/landing/FeaturesSection';
import { SecuritySection } from '@/components/landing/SecuritySection';
import { DownloadCTA } from '@/components/landing/DownloadCTA';

export default function HomePage() {
  return (
    <>
      <HeroSection />
      <FeaturesSection />
      <SecuritySection />
      <DownloadCTA />
    </>
  );
}
