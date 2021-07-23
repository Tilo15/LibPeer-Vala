using LibPeer.Protocols.Stp.Sessions;
using LibPeer.Protocols.Mx2;

namespace LibPeer.Protocols.Stp.Streams {

    public class StpInputStream : InputStream {

        private IngressSession session;

        private uint8[] unread_data;
        private Cond data_cond = Cond();
        private Mutex data_mutex = Mutex();

        public InstanceReference target { get { return session.target; }}
        public uint8[] session_id { get { return session.identifier; }}

        public StpInputStream(IngressSession session) {
            this.session = session;
            session.incoming_app_data.connect(handle_data);
        }

        private void handle_data(uint8[] data) {
            data_mutex.lock();
            unread_data = new Util.ByteComposer().add_byte_array(unread_data).add_byte_array(data).to_byte_array();
            data_cond.broadcast();
            data_mutex.unlock();
        }

        public override bool close (GLib.Cancellable? cancellable) {
            session.close();
            return true;
        }

        public override ssize_t read(uint8[] buffer, GLib.Cancellable? cancellable = null) throws GLib.IOError {
            data_mutex.lock();
            while(unread_data.length < buffer.length) {
                data_cond.wait(data_mutex);
            }

            for(int i = 0; i < buffer.length; i++) {
                buffer[i] = unread_data[i];
            }
            unread_data = unread_data[buffer.length:unread_data.length];
            data_mutex.unlock();
            return buffer.length;
        }

    }

}