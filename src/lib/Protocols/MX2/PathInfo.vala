
namespace LibPeer.Protocols.Mx2 {

    public class PathInfo {

        public unowned List<InstanceReference> repeaters { get; protected set; }

        public PathInfo return_path {
            owned get {
                var path = repeaters.copy_deep((m) => m);
                path.reverse();
                return new PathInfo(path);
            }
        }

        public PathInfo(List<InstanceReference> repeaters) {
            this.repeaters = repeaters;
        }

        public void serialise(OutputStream stream) throws IOError {
            // Write number of repeaters
            stream.write({(uint8)repeaters.length()});

            // Write the repeaters
            foreach (var repeater in repeaters) {
                repeater.serialise(stream);
            }
        }

        public PathInfo.from_stream(InputStream stream) throws IOError, Error {
            // Get number of repeaters
            uint8 repeater_count = stream.read_bytes(1).get(0);

            // Create list
            repeaters = new List<InstanceReference>();

            // Read repeaters
            for (uint8 i = 0; i < repeater_count; i++) {
                repeaters.append(new InstanceReference.from_stream(stream));
            }
        }

        public PathInfo.empty() {
            this(new List<InstanceReference>());
        }
    }

}