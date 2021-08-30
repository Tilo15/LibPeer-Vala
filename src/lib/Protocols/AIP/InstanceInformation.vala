using LibPeer.Protocols.Mx2;
using LibPeer.Networks;

namespace LibPeer.Protocols.Aip {

    public class InstanceInformation {

        public InstanceReference instance_reference { get; private set; }

        public PeerInfo[] connection_methods { get; private set; }

        public InstanceInformation(InstanceReference instance, PeerInfo[] methods) {
            instance_reference = instance;
            connection_methods = methods;
        }

        public void serialise(OutputStream stream) throws IOError, Error {
            var dos = new DataOutputStream(stream);
            dos.byte_order = DataStreamByteOrder.BIG_ENDIAN;

            // Write instance reference
            instance_reference.serialise(dos);
            
            // Write number of connection methods
            dos.put_byte((uint8)connection_methods.length);

            // Write connection methods
            foreach (var method in connection_methods) {
                method.serialise(dos);
            }
        }

        public InstanceInformation.from_stream(InputStream stream) throws IOError, Error {
            var dis = new DataInputStream(stream);
            dis.byte_order = DataStreamByteOrder.BIG_ENDIAN;

            // Read the instance reference
            instance_reference = new InstanceReference.from_stream(dis);

            // Read number of connection methods
            var method_count = dis.read_byte();

            // Read conneciton methods
            connection_methods = new PeerInfo[method_count];
            for (int i = 0; i < method_count; i++) {
                connection_methods[i] = PeerInfo.deserialise(stream);
            }
        }

    }

}