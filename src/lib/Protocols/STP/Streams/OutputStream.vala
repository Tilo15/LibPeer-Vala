using LibPeer.Protocols.Stp.Sessions;
using LibPeer.Protocols.Mx2;

namespace LibPeer.Protocols.Stp.Streams {

    public class StpOutputStream : OutputStream {

        private EgressSession session;
        public InstanceReference target { get { return session.target; }}
        public uint8[] session_id { get { return session.identifier; }}

        public StpOutputStream(EgressSession session) {
            this.session = session;
        }

        public override bool close (GLib.Cancellable? cancellable) {
            session.close();
            return true;
        }

        public override ssize_t write(uint8[] buffer, GLib.Cancellable? cancellable = null) throws IOError {
            Cond cond = Cond();
            Mutex mutex = Mutex();
            IOError error_result = null;
            bool complete = false;
            var tracker = session.queue_send(buffer);
            tracker.on_complete.connect(() => {
                mutex.lock();
                complete = true;
                cond.broadcast();
                mutex.unlock();
            });
            tracker.on_error.connect(e => {
                mutex.lock();
                error_result = e;
                complete = true;
                cond.broadcast();
                mutex.unlock();
            });
            
            mutex.lock();
            while(!complete) {
                cond.wait(mutex);
            }

            if(error_result != null) {
                throw error_result;
            }
            return buffer.length;
        }
    }

}