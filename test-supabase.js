const supabaseUrl = 'https://npkpfopaqpsbohywlhjf.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5wa3Bmb3BhcXBzYm9oeXdsaGpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0ODg1MzIsImV4cCI6MjA5MzA2NDUzMn0.Cq_drn7edTGpTnZ1WYBiXtuHUmQdNQwlkIi_AlhQ87A';

async function testRpc(rpcName) {
  const url = `${supabaseUrl}/rest/v1/rpc/${rpcName}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json'
    }
  });
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    console.error(`Error RPC ${rpcName}:`, data);
  } else {
    console.log(`RPC ${rpcName}: OK`);
  }
}

async function test() {
  await testRpc('is_global_admin');
}

test();
