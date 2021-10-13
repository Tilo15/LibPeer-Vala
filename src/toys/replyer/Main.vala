using LibPeer.Networks.Simulation;

namespace NumericReplyer {

    class Main : Object {

        public static int main(string[] args) {
            print("Replyer\n");
            int count = int.parse(args[1]);

            Conduit conduit = new Conduit();

            Replyer[] pingas = new Replyer[count];
            for (int i = 0; i < count; i++){
                pingas[i] = new Replyer(i, conduit);
            }

            while(true) {};

            return 0;
        }
    }

}