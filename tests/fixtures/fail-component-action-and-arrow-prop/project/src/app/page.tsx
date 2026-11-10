import { Editor } from '@/components/editor';

export default function Home() {
  return <Editor onSave={saveAction} onCancel={() => 1} />;
}
