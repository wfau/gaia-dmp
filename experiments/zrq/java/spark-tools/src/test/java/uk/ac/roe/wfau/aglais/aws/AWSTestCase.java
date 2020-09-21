/*
 *  Copyright (C) 2020 Royal Observatory, University of Edinburgh, UK
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

package uk.ac.roe.wfau.aglais.aws;

import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;

import org.apache.hadoop.conf.Configuration ;
import org.apache.hadoop.fs.FileStatus;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.LocatedFileStatus;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.fs.RemoteIterator;
import org.apache.hadoop.fs.s3a.S3AFileSystem;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.stereotype.Component;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.junit4.SpringJUnit4ClassRunner;

import junit.framework.TestCase;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
@RunWith(
        SpringJUnit4ClassRunner.class
        )
@ContextConfiguration(
    locations = {
        "classpath:component-config.xml"
        }
    )
public class AWSTestCase
extends TestCase
    {
    /**
     * Public constructor.
     *
     */
    public AWSTestCase()
        {
        super();
        }

    /**
     * Test things.
     * @throws URISyntaxException
     * @throws IOException
     *
     */
    @Test
    public void test002() throws URISyntaxException, IOException
        {
        log.info("Starting test run");
        /*
         *
        AWSCredentialsProvider creds = new StaticCredentialsProvider(
            new BasicAWSCredentials(
                "",
                ""
                )
            );
         *
         */

        Configuration configuration = new Configuration();

        //configuration.set("fs.s3a.endpoint", "https://cumulus.openstack.hpc.cam.ac.uk:6780/swift/v1/AUTH_21b4ae3a2ea44bc5a9c14005ed2963af/");
        configuration.set("fs.s3a.endpoint", "https://cumulus.openstack.hpc.cam.ac.uk:6780");
        configuration.set("fs.s3a.path.style.access", "true");
        configuration.set("fs.s3a.list.version", "2");
        configuration.set("fs.s3a.bucket.probe", "0");
        configuration.set("fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.AnonymousAWSCredentialsProvider");
        //configuration.set("fs.s3a.access.key", "");
        //configuration.set("fs.s3a.secret.key", "");

        URI baseuri = new URI(
//          "s3a://gaia-dr2-parquet"
            "s3a://albert"
            );

        S3AFileSystem fs = (S3AFileSystem) FileSystem.get(
            baseuri,
            configuration
            );

        Path basepath = new Path(
            "/"
            );

        FileStatus check = fs.getFileStatus(
            basepath
            );

        int count = 0 ;

        if (check.isDirectory())
            {
            //RemoteIterator<FileStatus> iter = fs.listStatusIterator(basepath);
            RemoteIterator<LocatedFileStatus> iter = fs.listFiles(basepath, false);
            for(count = 0 ; iter.hasNext() ; count++)
                {
                FileStatus status = iter.next();
                log.debug("Node [{}][{}]", count, status.getPath());
                }
            }
        log.debug("Result [{}]", count);
        assertEquals(2, count);
        }
    }
