import time
import unittest
import subprocess
import tempfile
import datetime
from orthanc_api_client import OrthancApiClient, ChangeType
from orthanc_api_client import helpers
import pathlib
import os
import logging

from orthanc_tools import OrthancCloner, ClonerMode, OrthancMonitor, OrthancTestDbPopulator, PacsMigrator, OrthancComparator, OrthancForwarder, ForwarderMode, ForwarderDestination

here = pathlib.Path(__file__).parent.resolve()

logger = logging.getLogger('dicom-web-forwarder')
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
ch.setFormatter(formatter)
logger.addHandler(ch)

label = "MYLABEL"

class TestForwarder(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        subprocess.run(["docker", "compose", "down", "-v"], cwd=here)
        subprocess.run(["docker", "compose", "up", "-d"], cwd=here)

        cls.oa = OrthancApiClient('http://localhost:10042')
        cls.oa.wait_started()
        cls.ob = OrthancApiClient('http://localhost:10043', user='demo', pwd='demo')
        cls.ob.wait_started()

    @classmethod
    def tearDownClass(cls):
        subprocess.run(["docker", "compose", "down", "-v"], cwd=here)


    def test_studies_are_labeled(self):
        self.oa.delete_all_content()
        self.ob.delete_all_content()

        # let's fill the orthanc A (10 studies, = circular memory size)
        populator_a = OrthancTestDbPopulator(api_client=self.oa, studies_count=10, random_seed=42, series_count = 1, instances_count=1)
        populator_a.execute()

        # lua will forward to the orthanc B and tag them
        helpers.wait_until(lambda: len(self.oa.studies.get_all_ids()) == 0, timeout=10)

        b_ids = self.ob.studies.get_all_ids()
        self.assertEqual(len(b_ids), 10)

        # let's check the labeling
        for id in b_ids:
            self.assertEqual(self.ob.studies.get_labels(id)[0], label)

        self.oa.delete_all_content()
        self.ob.delete_all_content()

        # let's fill the orthanc A again (10 studies, = circular memory size)
        populator_a = OrthancTestDbPopulator(api_client=self.oa, studies_count=10, random_seed=42, series_count=1, instances_count=1)
        populator_a.execute()

        # lua will forward to the orthanc B and shouldn't tag them (because the ids are in the circular memory)
        helpers.wait_until(lambda: len(self.oa.studies.get_all_ids()) == 0, timeout=10)

        b_ids = self.ob.studies.get_all_ids()
        self.assertEqual(len(b_ids), 10)

        # let's check the labeling
        self.assertEqual(len(self.ob.get_all_labels()), 0)

if __name__ == '__main__':
    logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    unittest.main()

