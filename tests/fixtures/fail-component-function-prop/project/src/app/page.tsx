import { Form } from '@/components/form';

export default function Home() {
  return <Form onSubmit={function (e) { e.preventDefault(); }} />;
}
