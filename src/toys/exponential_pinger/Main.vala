using LibPeer.Networks.Simulation;

namespace ExponentialPinger {

    class Main : Object {

        public static int main(string[] args) {
            print("Exponential Pinger\n");

            Conduit conduit = new Conduit();

            Pinger[] pingas = new Pinger[10];
            for (int i = 0; i < 10; i++){
                pingas[i] = new Pinger(conduit);
            }

            while(true) {};

            return 0;
        }
    }

}