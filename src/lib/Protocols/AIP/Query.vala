using LibPeer.Protocols.Mx2;
using Gee;

namespace LibPeer.Protocols.Aip {

    public class Query {

        public Bytes identifier { get; internal set; }

        public Bytes data { get; internal set; }

        public uint8 max_replies { get; internal set; }

        public uint8 hops { get; internal set; }

        public InstanceReference[] return_path { get; internal set; }

        public signal void on_answer(InstanceInformation answer);

        public void serialise(OutputStream stream) throws IOError, Error {
            var dos = new DataOutputStream(stream);
            dos.byte_order = DataStreamByteOrder.BIG_ENDIAN;

            // Write query identifier
            dos.write_bytes(identifier);

            // Send header data
            dos.put_byte(hops);
            dos.put_byte(max_replies);
            dos.put_uint16((uint16)data.length);
            dos.put_byte((uint8)return_path.length);

            // Serialise the return path
            foreach (var reference in return_path) {
                print("Instance reference serialisation for return path begins\n");
                reference.serialise(dos);
                print("Instance reference serialisation for return path ends\n");
            }

            // Write the query data
            dos.write_bytes(data);
        }

        public Query.from_stream(InputStream stream){
            var dis = new DataInputStream(stream);
            //  dis.buffer_size = 2;
            dis.byte_order = DataStreamByteOrder.BIG_ENDIAN;

            // Read the identifier
            print("\tIdentifier\n");
            identifier = dis.read_bytes(16);

            // Read header data
            print("\tHops\n");
            hops = dis.read_byte();
            print("\tMax Replies\n");
            max_replies = dis.read_byte();
            print("\tData length\n");
            var data_length = dis.read_uint16();
            print(@"\tQuery data length $(data_length)\n");
            var return_path_size = dis.read_byte();
            print(@"\tReturn path size $(return_path_size)\n");

            // Deserialise return path
            return_path = new InstanceReference[return_path_size];
            for(var i = 0; i < return_path_size; i++) {
                return_path[i] = new InstanceReference.from_stream(dis);
            }

            print("\tRead query data\n");

            // Read the query data
            data = dis.read_bytes(data_length);
            print(@"\tDone $(data.length)\n");
        }

        internal void append_return_hop(InstanceReference instance) {
            var paths = return_path;
            return_path = new InstanceReference[paths.length + 1];
            return_path[paths.length] = instance;
            for(int i = 0; i < paths.length; i++) {
                return_path[i] = paths[i];
            }
        }

        public Query(Bytes data, uint8 max_replies = 10, uint8 hops = 0, InstanceReference[] return_path = new InstanceReference[0], Bytes? identifier = null) {
            if(identifier == null) {
                uint8[] uuid = new uint8[16];
                UUID.generate_random(uuid);
                this.identifier = new Bytes(uuid);
            }
            this.data = data;
            this.max_replies = max_replies;
            this.hops = hops;
            this.return_path = return_path;
        }

    }

}