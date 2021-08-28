using Gee;

namespace LibPeer.Util {

    private class TimeoutObject<T> {
        public T object;
        public int64 timestamp;

        public void touch() {
            timestamp = get_monotonic_time();
        }

        public TimeoutObject(T obj) {
            object = obj;
            touch();
        }
    }

    public class TimeoutMap<K, V> {

        public TimeoutMap (int timeout, owned HashDataFunc<K>? key_hash_func = null, owned EqualDataFunc<K>? key_equal_func = null, owned EqualDataFunc<V>? value_equal_func = null) {
            EqualDataFunc<TimeoutObject<V>> unwrapped_value_equal_func = (a, b) => value_equal_func(a.object, b.object);
            map = new ConcurrentHashMap<K, TimeoutObject<V>> (key_hash_func, key_equal_func, unwrapped_value_equal_func);
            this.timeout = timeout;
            timeout_fuzz_ms = 10000;
        }

        public int timeout { get; set; }
        public int timeout_fuzz_ms { get; set; }

        private int64 last_clean = 0;

        private ConcurrentHashMap<K, TimeoutObject<V>> map;

        public void @set(K key, V value) {
            map.set(key, new TimeoutObject<V>(value));
        }

        public V @get(K key) {
            clean();
            var to = map.get(key);
            to.touch();
            return to.object;
        }

        public bool has_key(K key) {
            clean();
            lock(map) {
                return map.has_key(key);
            }
        }

        public bool unset(K key, out V value) {
            lock(map) {
                TimeoutObject<V> wrapped_value;
                bool result = map.unset(key, out wrapped_value);
                if(result) {
                    value = wrapped_value.object;
                }
                return result;
            }
        }

        public void clear() {
            lock(map) {
                map.clear();
            }
        }

        public void clean() {
            if(last_clean > get_monotonic_time() - (timeout_fuzz_ms * 1000)) {
                return;
            }
            lock(map) {
                int64 min_timestamp = get_monotonic_time() - (timeout * 1000000);
                foreach (var key in map.keys) {
                    var to = map.get(key);
                    if(to.timestamp < min_timestamp) {
                        map.unset(key);
                    }
                }
                last_clean = get_monotonic_time();
            }
        }
        
    }

}