import testbase
import unittest

def wordCount(rdd):
    """
    Counts the words in an RDD
    """
    wcntRdd = rdd.flatMap(lambda line: line.split()).\
        map(lambda word: (word, 1)).\
        reduceByKey(lambda fa, fb: fa + fb)
    return wcntRdd


class TestWordCount(testbase.ReusedPySparkTestCase):
    def test_word_count(self):
        """
        Test the word count method
        Assert that the word counts is correct
        """
        rdd = self.sc.parallelize(["a b c d", "a c d e", "a d e f"])
        res = wordCount(rdd)
        res = res.collectAsMap()
        expected = {"a":3, "b":1, "c":2, "d":3, "e":2, "f":1}
        self.assertEqual(res,expected)


if __name__ == '__main__':
    if __name__ == '__main__':
        unittest.main()
