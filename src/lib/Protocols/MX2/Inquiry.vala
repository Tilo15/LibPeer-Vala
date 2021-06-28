using LibPeer.Util;

namespace LibPeer.Protocols.Mx2 {

    public class Inquiry : Object {

        public Bytes id { get; private set; }

        public InstanceReference target { get; private set; }

        public signal void complete(bool instance_found, int delay);

        private Timer delay_timer;

        private ThreadTimer timeout_thread;

        public Inquiry(InstanceReference target, int timeout = 10000) {
            uint8[] uuid = new uint8[16];
            UUID.generate_random(uuid);
            id = new Bytes(uuid);

            this.target = target;
            
            delay_timer = new Timer();
            delay_timer.start();

            timeout_thread = new ThreadTimer(timeout, () => {
                delay_timer.stop();
                ulong microseconds;
                complete(false, (int)(delay_timer.elapsed(out microseconds) * 1000));
            });

            timeout_thread.start();
        }

        internal int response_received() {
            if (!timeout_thread.running) {
                return 0;
            }

            timeout_thread.cancel();
            delay_timer.stop();

            ulong microseconds;
            int milliseconds = (int)(delay_timer.elapsed(out microseconds) * 1000);
            complete(true, milliseconds);
            return milliseconds;
        }

    }

}