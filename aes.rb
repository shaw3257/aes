module Aes
  def mult a, b
    p = 0
    while(b != 0) do
      if (b & 1 != 0)
        p ^= a
      end
      if a >=128
        a = (a << 1) ^ 0x11B
      else
        a = a << 1
      end
      b = b >> 1
    end
    p
  end

  def div d, n
    q = 0
    v = (msb(d) - msb(n))
    n = n << v
    v.downto(0).each do |i|
      if (msb(d) == msb(n))
        d ^= n
        q |= 1 << i
      end
      n = n >> 1
    end
    [q, d]
  end

  def inverse a
    s = [283, a]
    t = [0, 1]
    while(s[0] != 1) do
      q,r = div(s[0], s[1])
      s.shift
      s << r
      t_new = t[0] ^ mult(t[1], q)
      t.shift
      t << t_new
    end
    t[0]
  end


  def msb num
    x = 0
    32.downto(0).each do |i|
     x = i; break if num & (1 << i) != 0
    end
    x
  end

  def sbox(b)
    return 0x63 if b == 0
    b = inverse(b)
    r = 0
    m = [
      [1,0,0,0,1,1,1,1],
      [1,1,0,0,0,1,1,1],
      [1,1,1,0,0,0,1,1],
      [1,1,1,1,0,0,0,1],
      [1,1,1,1,1,0,0,0],
      [0,1,1,1,1,1,0,0],
      [0,0,1,1,1,1,1,0],
      [0,0,0,1,1,1,1,1]
    ]
    t = 0
    m.each_with_index do |row, i|
      multiplier = 0
      row.each_with_index do |num, j|
        x = ((b & (1 << j)) == 0 ? 0 : num)
        multiplier ^= x
      end
      t |= (multiplier << i)
    end
    t ^ 99
  end


  def rcon i
    div((1 << i-1), 0x11B)[1]
  end

  def rotl word
    word << word.shift
  end

  def sub_word word
    word.map{ |b| sbox(b) }
  end

  def add_word w1, w2
    [w1[0] ^ w2[0], w1[1] ^ w2[1], w1[2] ^ w2[2], w1[3] ^ w2[3]]
  end

  def key_expansion(key)
    w = key.dup
    i = 4
    while(i < 4 * 11) do
      temp_word = w[i * 4 - 4..-1]
      if(i % 4 == 0)
        r = rotl(temp_word)
        s = sub_word(r)
        s[0] ^= rcon(i/4)
        temp_word = s
      end
      x = add_word(w[i * 4 - 16..i * 4 - 13], temp_word)
      w.concat x
      i += 1
    end
    w
  end

  def sub_bytes(state)
    state.map{ |e| sbox(e) }
  end

  def shift_rows state
    shift_row = -> (a, i) do
      t = a[i]
      3.downto(0).each do |j|
        s = a[i + 4*j]
        a[i + 4*j] = t
        t = s
      end
    end
    shift_row.call(state, 1)
    shift_row.call(state, 2)
    shift_row.call(state, 2)
    shift_row.call(state, 3)
    shift_row.call(state, 3)
    shift_row.call(state, 3)
    state
  end

  def mix_columns state
    s = []
    m = [
      [0x02, 0x03, 0x01, 0x01],
      [0x01, 0x02, 0x03, 0x01],
      [0x01, 0x01, 0x02, 0x03],
      [0x03, 0x01, 0x01, 0x02],
    ]
    (0..3).each do |i|
      m.each_with_index do |row, j|
        product = 0
        row.each_with_index do |e, k|
          product ^= mult(state[i*4 + k], e)
        end
        s[i*4 + j] = product
      end
    end
    s.each_with_index { |e,i| state[i] = e }
    state
  end

  def add_round_key state, key
    key.each_with_index { |e, i| state[i] ^= e }
    state
  end

  def cipher state, key
    w = key_expansion(key)
    add_round_key(state, w[0..15])
    s = state
    (1..9).each do |i|
      s = sub_bytes(s)
      s = shift_rows(s)
      s = mix_columns(s)
      s = add_round_key(s, w[i*16..i*16 + 15])
    end

    s = sub_bytes(s)
    s = shift_rows(s)
    s = add_round_key(s, w[10*16..-1])
    s
  end
end