/* Vala Bindings for LibSodium
 * Copyright (c) 2020 Billy Barrow <billyb@pcthingz.com>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */


 [CCode (cheader_filename = "sodium.h", lower_case_cprefix = "sodium_")]
 namespace Sodium {
 
   namespace Random {
     [CCode (cname = "randombytes_SEEDBYTES")]
     public const size_t SEED_BYTES;
   
     [CCode (cname = "randombytes_random")]
     public uint32 random();
   
     [CCode (cname = "randombytes_uniform")]
     public uint32 random_uniform(uint32 upper_bound);
   
     [CCode (cname = "randombytes_buf")]
     public void random_bytes(uint8[] buffer);
   
     [CCode (cname = "randombytes_buf_deterministic")]
     public void random_bytes_deterministic(uint8[] buffer, uint8[] seed);
   }
 
   namespace Symmetric {
     [CCode (cname = "crypto_secretbox_KEYBYTES")]
     public const size_t KEY_BYTES;
 
     [CCode (cname = "crypto_secretbox_NONCEBYTES")]
     public const size_t NONCE_BYTES;
 
     [CCode (cname = "crypto_secretbox_MACBYTES")]
     public const size_t MAC_BYTES;
 
     [CCode (cname = "crypto_secretbox_keygen")]
     private void key_gen([CCode (array_length = false)]uint8[] key);
 
     public uint8[] generate_key() {
       uint8[KEY_BYTES] key = new uint8[KEY_BYTES];
       key_gen(key);
       return key;
     }
 
     [CCode (cname = "crypto_secretbox_easy")]
     private void secretbox(
       [CCode (array_length = false)]uint8[] ciphertext,
       uint8[] message,
       [CCode (array_length = false)]uint8[] nonce,
       [CCode (array_length = false)]uint8[] key
     );
 
     public uint8[] encrypt(uint8[] message, uint8[] key, uint8[] nonce)
       requires (key.length == KEY_BYTES) 
       requires (nonce.length == NONCE_BYTES)
     {
       // Initialise array for ciphertext
       size_t ciphertext_size = MAC_BYTES + message.length;
       uint8[ciphertext_size] ciphertext = new uint8[ciphertext_size];
 
       // Encrypt
       secretbox(ciphertext, message, nonce, key);
 
       // Return ciphertext
       return ciphertext;
     }
 
     [CCode (cname = "crypto_secretbox_open_easy")]
     private int secretbox_open(
       [CCode (array_length = false)]uint8[] message,
       uint8[] ciphertext,
       [CCode (array_length = false)]uint8[] nonce,
       [CCode (array_length = false)]uint8[] key
     );
 
     public uint8[]? decrypt(uint8[] ciphertext, uint8[] key, uint8[] nonce)
       requires (ciphertext.length > MAC_BYTES)
       requires (key.length == KEY_BYTES) 
       requires (nonce.length == NONCE_BYTES)
     {
       // Initialise array for message
       size_t message_size = ciphertext.length - MAC_BYTES;
       uint8[message_size] message = new uint8[message_size];
 
       // Decrypt
       int status = secretbox_open(message, ciphertext, nonce, key);
 
       // Did it work?
       if(status != 0) {
         // No, return null
         return null;
       }
 
       return message;
     }
   }
   
   namespace Asymmetric {
 
     namespace Signing {
 
         [CCode (cname = "crypto_sign_PUBLICKEYBYTES")]
         public const size_t PUBLIC_KEY_BYTES;
 
         [CCode (cname = "crypto_sign_SECRETKEYBYTES")]
         public const size_t SECRET_KEY_BYTES;
 
         [CCode (cname = "crypto_sign_BYTES")]
         public const size_t MAX_HEADER_BYTES;
 
         [CCode (cname = "crypto_sign_keypair")]
         public void generate_keypair(
             [CCode (array_length = false)]uint8[] public_key,
             [CCode (array_length = false)]uint8[] secret_key)
             requires (public_key.length == PUBLIC_KEY_BYTES)
             requires (secret_key.length == SECRET_KEY_BYTES);
             
         [CCode (cname = "crypto_sign")]
         private void sign_message(
             [CCode (array_length = false)] uint8[] signed_message,
             out int signature_length,
             uint8[] message,
             [CCode (array_length = false)] uint8[] secret_key
         );
 
         public uint8[] sign(
             uint8[] message,
             uint8[] secret_key)
             requires (secret_key.length == SECRET_KEY_BYTES)
         {
             int signature_length;
             uint8[] signed_message = new uint8[MAX_HEADER_BYTES + message.length];
             sign_message(signed_message, out signature_length, message, secret_key);
             signed_message.resize(signature_length);
 
             return signed_message;
         }
 
         [CCode (cname = "crypto_sign_open")]
         private int sign_open(
             [CCode (array_length = false)] uint8[] message,
             out int message_length,
             uint8[] signed_message,
             [CCode (array_length = false)] uint8[] public_key
         );
 
         public uint8[]? verify(
             uint8[] signed_message,
             uint8[] public_key)
             requires (public_key.length == PUBLIC_KEY_BYTES)
         {
             int message_length;
             uint8[] message = new uint8[signed_message.length];
             if(sign_open(message, out message_length, signed_message, public_key) != 0) {
                 return null;
             }
             message.resize(message_length);
 
             return message;
         }
 
     }
 
     namespace Sealing {
 
         [CCode (cname = "crypto_box_PUBLICKEYBYTES")]
         public const size_t PUBLIC_KEY_BYTES;
 
         [CCode (cname = "crypto_box_SECRETKEYBYTES")]
         public const size_t SECRET_KEY_BYTES;
 
         [CCode (cname = "crypto_box_SEALBYTES")]
         public const size_t HEADER_BYTES;
 
         [CCode (cname = "crypto_box_keypair")]
         public void generate_keypair(
             [CCode (array_length = false)]uint8[] public_key,
             [CCode (array_length = false)]uint8[] secret_key)
             requires (public_key.length == PUBLIC_KEY_BYTES)
             requires (secret_key.length == SECRET_KEY_BYTES);
 
         [CCode (cname = "crypto_box_seal")]
         private void seal_message(
             [CCode (array_length = false)] uint8[] ciphertext,
             uint8[] message,
             [CCode (array_length = false)] uint8[] public_key
         );
 
         public uint8[] seal(uint8[] message, uint8[] public_key)
             requires (public_key.length == PUBLIC_KEY_BYTES)
         {
             uint8[] ciphertext = new uint8[HEADER_BYTES + message.length];
             seal_message(ciphertext, message, public_key);
             return ciphertext;
         }
 
         [CCode (cname = "crypto_box_seal_open")]
         private int seal_open(
             [CCode (array_length = false)] uint8[] message,
             uint8[] ciphertext,
             [CCode (array_length = false)] uint8[] public_key,
             [CCode (array_length = false)] uint8[] secret_key
         );
 
         public uint8[]? unseal(
             uint8[] ciphertext,
             uint8[] public_key,
             uint8[] secret_key) 
             requires (public_key.length == PUBLIC_KEY_BYTES)
             requires (secret_key.length == SECRET_KEY_BYTES)
             requires (ciphertext.length > HEADER_BYTES)
         {
             uint8[] message = new uint8[ciphertext.length - HEADER_BYTES];
             if(seal_open(message, ciphertext, public_key, secret_key) != 0){
                 return null;
             }
             return message;
         }
         
     }
 
   }
   
 
 }