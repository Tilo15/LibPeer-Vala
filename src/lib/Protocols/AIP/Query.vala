using LibPeer.Protocols.Mx2;
using Gee;

namespace LibPeer.Protocols.Aip {

    internal class Query {

        public Bytes identifier { get; set; }

        public Bytes data { get; set; }

        public uint8 max_replies { get; set; }

        public uint8 hops { get; set; }

        public InstanceReference[] return_path { get; set; }

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
                reference.serialise(dos);
            }

            // Write the query data
            dos.write_bytes(data);
        }

        public Query.from_stream(InputStream stream) throws IOError, Error{
            var dis = new DataInputStream(stream);
            dis.byte_order = DataStreamByteOrder.BIG_ENDIAN;

            // Read the identifier
            identifier = dis.read_bytes(16);

            // Read header data
            hops = dis.read_byte();
            max_replies = dis.read_byte();
            var data_length = dis.read_uint16();
            var return_path_size = dis.read_byte();

            // Deserialise return path
            return_path = new InstanceReference[return_path_size];
            for(var i = 0; i < return_path_size; i++) {
                return_path[i] = new InstanceReference.from_stream(dis);
            }

            // Read the query data
            data = stream.read_bytes(data_length);
        }

        public void append_return_hop(InstanceReference instance) {
            var paths = return_path;
            return_path = new InstanceReference[paths.length + 1];
            return_path[paths.length] = instance;
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