
namespace LibPeer.Util {

    internal class ThreadTimer {

        public bool running {
            get {
                return has_started && !has_been_canceled && !has_elapsed;
            }
        }

        private bool has_been_canceled = false;
        private bool has_elapsed = false;
        private bool has_started = false;
        
        private int timeout;
        private TimerFunc timer_func;
    

        public ThreadTimer(int timeout, TimerFunc timer_func) {
            this.timeout = timeout;
            this.timer_func = timer_func;
        }

        public void start() {
            if(this.has_started) {
                return;
            }

            this.has_started = true;
            ThreadFunc<bool> runner = () => {
                Thread<bool>.usleep(timeout * 1000);
                if(has_been_canceled) {
                    return false;
                }
                has_elapsed = true;
                timer_func();
                return true;
            };

            new Thread<bool>(@"$(timeout)ms timer thread", runner);
        }

        public void cancel() {
            has_been_canceled = true;
        }
    }

    internal delegate void TimerFunc();

}