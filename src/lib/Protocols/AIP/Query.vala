using LibPeer.Protocols.Mx2;
using LibPeer.Util;
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
            var dos = StreamUtil.get_data_output_stream(stream);

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

        public Query.from_stream(InputStream stream){
            var dis = StreamUtil.get_data_input_stream(stream);

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
            data = dis.read_bytes(data_length);
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