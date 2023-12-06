defmodule Platform.DuplicatesTest do
  use Platform.DataCase, async: true

  alias Platform.Workers.DuplicateDetector

  describe "hamming_distance" do
    test "hamming_distance/2 returns the hamming distance between two perceptual hashes" do
      assert DuplicateDetector.hamming_distance("5hJZnFmbWY4=", "5xNYjEmb2Y4=") == {:ok, 6}
      assert DuplicateDetector.hamming_distance("5hJZnFmbWY4=", "5hJZnFmbWY4=") == {:ok, 0}
      assert DuplicateDetector.hamming_distance("1203fhadsou", "whaoiadfasdf") ==
               {:error, :invalid_base64}
      assert DuplicateDetector.hamming_distance("aG8=", "YWRpb2FmZGZzaW8=") ==
               {:error, :unequal_length}
    end
  end
end
