import { Editor } from '@/components/editor';

async function saveAction() {
  'use server';
}

export default function Home() {
  return <Editor onSave={saveAction} />;
}
