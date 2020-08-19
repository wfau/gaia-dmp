import testbase
import unittest
from random import choice
from string import digits, ascii_lowercase
from datetime import datetime


def randomWordCount(sc, word_size, sample):
    """
    Generate a list of [sample] * random strings

    """

    chars = digits + ascii_lowercase
    seq = ["".join([choice(chars) for i in range(word_size)]) for j in range(sample)]
    data = sc.parallelize(seq)
    counts = data.map(lambda word: (word, 1)).reduceByKey(lambda a, b: a + b).top(5)
    dict(counts)

class TestRandomWordCount(testbase.PySparkTestBase):

    def test_word_count(self):
        """
        Test the word count method
        Assert that the time taken doesn't exceed x seconds

        """
        #TODO: make this configurable
        _CHANGE_ME_max_seconds = 5
        _CHANGE_ME_sample = 10000

        tick = datetime.now()
        randomWordCount(self.sc, 3, _CHANGE_ME_sample)
        tock = datetime.now()
        diff = tock - tick
        self.assertTrue(diff.seconds <=  _CHANGE_ME_max_seconds)

if __name__ == '__main__':
    if __name__ == '__main__':
        unittest.main()
