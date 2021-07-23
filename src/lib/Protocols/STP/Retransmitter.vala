
namespace LibPeer.Protocols.Stp {

    internal class Retransmitter {

        public uint64 interval { get; private set; }

        public int ttl { get; private set; }

        public uint64 last_called { get; private set; }

        public Func<int> action { get; private set; }

        public bool cancelled { get; private set; }

        public bool tick() {
            if(cancelled) {
                return false;
            }

            if(last_called < get_monotonic_time() - interval*1000) {
                ttl--;
                action(ttl);
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

        public Retransmitter(uint64 interval, int times, Func<int> action) {
            cancelled = false;
            this.interval = interval;
            ttl = times - 1;
            this.action = action;
        }

    }

}