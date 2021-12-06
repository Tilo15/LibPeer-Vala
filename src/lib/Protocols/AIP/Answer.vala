using LibPeer.Protocols.Mx2;
using Gee;

namespace LibPeer.Protocols.Aip {

    public class Answer {

        public Bytes in_reply_to { get; set; }

        public Bytes data { get; set; }

        public InstanceReference[] path { get; set; }

        public void serialise(OutputStream stream) throws IOError {
            var dos = new DataOutputStream(stream);
            dos.byte_order = DataStreamByteOrder.BIG_ENDIAN;

            dos.write_bytes(in_reply_to);

            dos.put_int32(data.length);
            dos.put_byte((uint8)path.length);

            foreach (var reference in path) {
                reference.serialise(dos);
            }

            dos.write(data.get_data());
        }

        public Answer.from_stream(InputStream stream) throws IOError{
            var dis = new DataInputStream(stream);
            dis.byte_order = DataStreamByteOrder.BIG_ENDIAN;

            // What is this in reply to?
            in_reply_to = dis.read_bytes(16);

            var data_length = dis.read_int32();
            var path_size = dis.read_byte();
            print(@"Reading $(path_size) instance references\n");

            path = new InstanceReference[path_size];

            for(var i = 0; i < path_size; i++) {
                path[i] = new InstanceReference.from_stream(dis);
            }

            print(@"Reading $(data_length) bytes of answer data\n");

            data = dis.read_bytes(data_length);
        }

        public InstanceReference pop_path() {
            var reference = path[path.length - 1];
            var old_path = path;
            path = new InstanceReference[old_path.length - 1];
            for(int i = 0; i < path.length; i++) {
                path[i] = old_path[i];
            }
            return reference;
        }

    }
}