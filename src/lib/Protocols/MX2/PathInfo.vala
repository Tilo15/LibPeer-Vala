
namespace LibPeer.Protocols.Mx2 {

    public class PathInfo {

        public Gee.LinkedList<InstanceReference> repeaters { get; private set; }

        public PathInfo return_path {
            owned get {
                var path = repeaters.to_array();
                var reversed = new Gee.LinkedList<InstanceReference>();
                for(var i = reversed.size; i > 0; i++) {
                    reversed.add(path[i-1]);
                }
                return new PathInfo(reversed);
            }
        }

        public PathInfo(Gee.LinkedList<InstanceReference> repeaters) {
            this.repeaters = repeaters;
        }

        public void serialise(OutputStream stream) throws IOError {
            // Write number of repeaters
            stream.write({(uint8)repeaters.size});

            // Write the repeaters
            foreach (var repeater in repeaters) {
                repeater.serialise(stream);
            }
        }

        public PathInfo.from_stream(InputStream stream) throws IOError, Error {
            // Get number of repeaters
            uint8 repeater_count = stream.read_bytes(1).get(0);

            // Create list
            repeaters = new Gee.LinkedList<InstanceReference>();

            // Read repeaters
            for (uint8 i = 0; i < repeater_count; i++) {
                repeaters.add(new InstanceReference.from_stream(stream));
            }
        }

        public PathInfo.empty() {
            this(new Gee.LinkedList<InstanceReference>());
        }
    }

}