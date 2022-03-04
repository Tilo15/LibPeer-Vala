using LibPeer.Protocols.Mx2;
using LibPeer.Networks;
using LibPeer.Util;

namespace LibPeer.Protocols.Aip {

    public class InstanceInformation : Object {

        public InstanceReference instance_reference { get; private set; }

        public PeerInfo[] connection_methods { get; private set; }

        public InstanceInformation.from_info(InstanceReference instance, PeerInfo[] methods) {
            instance_reference = instance;
            connection_methods = methods;
        }

        public virtual void serialise(OutputStream stream) throws IOError, Error {
            var dos = StreamUtil.get_data_output_stream(stream);

            // Write instance reference
            instance_reference.serialise(dos);
            
            // Write number of connection methods
            dos.put_byte((uint8)connection_methods.length);

            //  print(@"$(connection_methods.length) Connection methods\n");
            // Write connection methods
            foreach (var method in connection_methods) {
                method.serialise(dos);
            }
        }

        public InstanceInformation.from_stream(InputStream stream) {
            fill_from_stream(stream);
        }

        protected void fill_from_stream(InputStream stream)  throws IOError, Error {
            var dis = StreamUtil.get_data_input_stream(stream);

            // Read the instance reference
            instance_reference = new InstanceReference.from_stream(dis);

            // Read number of connection methods
            var method_count = dis.read_byte();
            //  print(@"Reading $(method_count) connection methods\n");

            // Read conneciton methods
            connection_methods = new PeerInfo[method_count];
            for (int i = 0; i < method_count; i++) {
                connection_methods[i] = PeerInfo.deserialise(dis);
            }
        }

        protected void copy_from(InstanceInformation info) {
            instance_reference = info.instance_reference;
            connection_methods = info.connection_methods;
        }

    }

}