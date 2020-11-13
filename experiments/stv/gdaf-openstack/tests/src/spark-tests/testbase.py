import os
import sys
import unittest
from datetime import datetime


SPARK_HOME = os.environ["SPARK_HOME"]
os.path.join(SPARK_HOME)
sys.path.insert(1, os.path.join(SPARK_HOME, 'python'))
sys.path.insert(1, os.path.join(SPARK_HOME, 'python', 'pyspark'))
sys.path.insert(1, os.path.join(SPARK_HOME, 'python', 'build'))
sys.path.insert(1, os.path.join(SPARK_HOME, 'python', 'lib/py4j-0.8.2.1-src.zip'))
pyspark_python =  sys.executable
os.environ['PYSPARK_PYTHON'] = pyspark_python

from pyspark.conf import SparkConf
from pyspark.context import SparkContext


sc_values = {}

class PySparkTestBase(unittest.TestCase):
    """
    Reusable PySpark Test Case Class
    Share a Spark Context

    """

    @classmethod
    def setUpClass(cls):
        conf = SparkConf().setMaster("local[2]") \
            .setAppName(cls.__name__) \
            .set("spark.authenticate.secret", "test")
        cls.sc = SparkContext(conf=conf)
        sc_values[cls.__name__] = cls.sc

    @classmethod
    def tearDownClass(cls):
        sc_values.clear()
        cls.sc.stop()

