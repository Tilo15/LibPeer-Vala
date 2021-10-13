using LibPeer.Protocols.Stp.Sessions;
using LibPeer.Protocols.Mx2;

namespace LibPeer.Protocols.Stp.Streams {

    public class StpOutputStream : OutputStream {

        private EgressSession session;
        public InstanceReference target { get { return session.target; }}
        public uint8[] session_id { get { return session.identifier; }}

        Cond sendop_cond = Cond();
        Mutex sendop_mutex = Mutex();
        private int send_operations = 0;

        public signal void reply(StpInputStream stream);

        public StpOutputStream(EgressSession session) {
            this.session = session;
            this.session.received_reply.connect(s => reply(new StpInputStream(s)));
        }

        public override bool close (GLib.Cancellable? cancellable) {
            sendop_mutex.lock();
            while(send_operations != 0) {
                print("[STP] Waiting for operations to complete before closing stream\n");
                sendop_cond.wait(sendop_mutex);
            }
            session.close();
            return true;
        }

        public override ssize_t write(uint8[] buffer, GLib.Cancellable? cancellable = null) throws IOError {
            send_operations++;
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

            send_operations--;
            sendop_mutex.lock();
            sendop_cond.broadcast();
            sendop_mutex.unlock();

            if(error_result != null) {
                throw error_result;
            }
            return buffer.length;
        }
    }

}