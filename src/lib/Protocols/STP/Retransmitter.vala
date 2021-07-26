
namespace LibPeer.Protocols.Stp {

    internal abstract class Retransmitter {

        public uint64 interval { get; protected set; }

        public int ttl { get; protected set; }

        public uint64 last_called { get; private set; }

        public bool cancelled { get; protected set; }

        public bool tick() {
            if(cancelled) {
                return false;
            }

            if(last_called < get_monotonic_time() - interval*1000) {
                ttl--;
                do_task();
                last_called = get_monotonic_time();

                if(ttl == 0) {
                    cancel();
                    return false;
                }
            }
            return true;
        }

        public void cancel() {
            cancelled = true;
        }

        protected abstract void do_task();

    }

}