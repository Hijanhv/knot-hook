import Providers from "../providers";

export default function ContractStateLayout({ children }: { children: React.ReactNode }) {
  return <Providers>{children}</Providers>;
}
