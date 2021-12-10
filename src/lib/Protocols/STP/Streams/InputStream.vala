using LibPeer.Protocols.Stp.Sessions;
using LibPeer.Protocols.Mx2;

namespace LibPeer.Protocols.Stp.Streams {

    public class StpInputStream : InputStream {

        private IngressSession session;

        private uint8[] unread_data;
        private Cond data_cond = Cond();
        private Mutex data_mutex = Mutex();

        private int pending_data = 0;

        public InstanceReference origin { get { return session.target; }}
        public uint8[] session_id { get { return session.identifier; }}

        public StpInputStream(IngressSession session) {
            this.session = session;
            session.incoming_app_data.connect(handle_data);
            session.session_closed.connect(handle_close);
        }

        private void handle_data(uint8[] data) {
            //  print("*** HANDLE DATA START\n");
            pending_data ++;
            data_mutex.lock();
            //  print(@"InputStream:\n\tAdding \"$(new Util.ByteComposer().add_byte_array(data).to_escaped_string())\"\n\tTo: \"$(new Util.ByteComposer().add_byte_array(unread_data).to_escaped_string())\"\n");
            unread_data = new Util.ByteComposer().add_byte_array(unread_data).add_byte_array(data).to_byte_array();
            pending_data --;
            data_cond.broadcast();
            data_mutex.unlock();
            //  print("*** HANDLE DATA RETURN\n");
        }

        private void handle_close() {
            //  print("*** HANDLE CLOSE START\n");
            data_mutex.lock();
            data_cond.broadcast();
            data_mutex.unlock();
            //  print("*** HANDLE DATA RETURN\n");
        }

        public override bool close (GLib.Cancellable? cancellable) {
            session.close();
            return true;
        }

        public override ssize_t read(uint8[] buffer, GLib.Cancellable? cancellable = null) throws GLib.IOError {
            data_mutex.lock();
            while(unread_data.length < buffer.length && (session.open && pending_data == 0)) {
                data_cond.wait(data_mutex);
            }
            var available_data = unread_data.length < buffer.length ? unread_data.length : buffer.length;
            //  print(@"Read $(available_data) of $(buffer.length) bytes\n");
            for(int i = 0; i < available_data; i++) {
                buffer[i] = unread_data[i];
            }
            //  print(@"Read:\n\t\"$(new Util.ByteComposer().add_byte_array(buffer).to_escaped_string())\"\n\tof: \"$(new Util.ByteComposer().add_byte_array(unread_data).to_escaped_string())\"\n");
            unread_data = unread_data[available_data:unread_data.length];
            data_mutex.unlock();



            return available_data;
        }

    }

}