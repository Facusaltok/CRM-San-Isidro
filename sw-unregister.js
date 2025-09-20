// Call this once to remove any old SW + caches
export async function nukeServiceWorkers(){
  try{
    if ('serviceWorker' in navigator){
      const regs = await navigator.serviceWorker.getRegistrations();
      await Promise.all(regs.map(r => r.unregister()));
    }
    if (window.caches){
      const keys = await caches.keys();
      await Promise.all(keys.map(k => caches.delete(k)));
    }
    console.log('Service workers & caches cleared');
  }catch(e){ console.warn('SW cleanup error', e); }
}
