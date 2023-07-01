using LibPeer.Util;

namespace LibPeer.Protocols.Stp {

    internal abstract class Retransmitter {

        protected Retransmitter(int interval, int retries) {
            this.ttl = retries;
            timer = new ThreadTimer(interval, () => tick());
            last_called = 0;
        }

        private ThreadTimer timer;

        public uint interval { get; protected set; }

        public int ttl { get; protected set; }

        public uint64 last_called { get; private set; }

        public void begin() {
            tick();
        }

        private void tick() {
            if(timer.is_canceled) {
                return;
            }

            if(last_called < get_monotonic_time() - interval*1000) {
                if(ttl > 0) {
                    ttl--;
                }
                do_task();
                last_called = get_monotonic_time();

                if(ttl == 0) {
                    cancel();
                    return;
                }
            }
            
            timer.start();
        }

        protected abstract void do_task();

        public void cancel() {
            timer.cancel();
        }

        ~ Retransmitter() {
            timer.cancel();
        }

    }

}