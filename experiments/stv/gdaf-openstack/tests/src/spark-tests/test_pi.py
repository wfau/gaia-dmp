import testbase
import unittest
from datetime import datetime
import random

def inside(p):
    """
    Helper method for piCalculation
    """
    x, y = random.random(), random.random()
    return x*x + y*y < 1


def piCalculation(sc, sample):
    """
    Calculate the value of pi
    """
    count = sc.parallelize(xrange(0, sample)) \
                 .filter(inside).count()
    return 4.0 * count / sample

class TestRandomWordCount(testbase.PySparkTestBase):

    def test_word_count(self):
        """
        Test the word count method
        Assert that the time taken doesn't exceed x seconds

        """
        #TODO: make these configurable
        _CHANGE_ME_max_seconds = 5
        _CHANGE_ME_sample = 100000

        tick = datetime.now()
        piCalculation(self.sc, _CHANGE_ME_sample)
        tock = datetime.now()
        diff = tock - tick
        self.assertTrue(diff.seconds <=  _CHANGE_ME_max_seconds)

if __name__ == '__main__':
    if __name__ == '__main__':
        unittest.main()
