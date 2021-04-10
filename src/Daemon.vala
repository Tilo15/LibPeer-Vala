using Gee;

namespace Hlpce {

    class Daemon : Object {

        public static int main(string[] args) {
            stderr.printf("HLPCE: High Level Peer Communication Engine (LibPeer-Vala) v0.1\n");

            uint8[] data = {0,1,2,3};
            var test = new MemoryInputStream.from_data(data);
            var reader1 = new DataInputStream(test);
            stderr.printf(@"$(reader1.read_byte()) and then $(reader1.read_byte())\n");

            var reader2 = new DataInputStream(test);
            stderr.printf(@"$(reader1.read_byte()) and then $(reader1.read_byte())\n");

            uint8[] arr1 = {2, 4, 6, 8};
            uint8[] arr2 = {1, 3, 5, 7};
            uint8[] arr3 = {2, 4, 6, 8};
            uint8[] arr4 = {1, 3, 5, 7};

            var b1 = new Bytes(arr1);
            var b2 = new Bytes(arr2);
            var b3 = new Bytes(arr3);
            var b4 = new Bytes(arr4);
            var b5 = new Bytes(arr1);
            var b6 = new Bytes(arr2);
            var b7 = new Bytes(arr3);
            var b8 = new Bytes(arr4);

            var map = new Gee.HashMap<Bytes, string>((a) => a.hash(), (a, b) => a.compare(b) == 0);
            map.set(b1, "Even");
            map.set(b2, "Odd");

            stderr.printf(@"$(map.get(b3)) $(map.get(b4))\n");

            return 0;
        }
    }

}