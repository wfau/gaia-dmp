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
import java.util.Iterator;
import java.util.List;

import org.apache.hadoop.conf.Configuration ;
import org.apache.hadoop.fs.FileStatus;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.fs.RemoteIterator;
import org.apache.hadoop.fs.s3a.DefaultS3ClientFactory;
import org.apache.hadoop.fs.s3a.S3AFileSystem;
import org.apache.hadoop.fs.s3a.S3ClientFactory;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.stereotype.Component;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.junit4.SpringJUnit4ClassRunner;

import com.amazonaws.auth.AWSCredentials;
import com.amazonaws.auth.AWSCredentialsProvider ;
import com.amazonaws.internal.StaticCredentialsProvider;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.model.ObjectListing;
import com.amazonaws.services.s3.model.S3ObjectSummary;

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

        configuration.set("fs.s3a.endpoint", "https://cumulus.openstack.hpc.cam.ac.uk:6780/swift/v1/AUTH_21b4ae3a2ea44bc5a9c14005ed2963af/");
        configuration.set("fs.s3a.access.key", "<empty>");
        configuration.set("fs.s3a.secret.key", "<empty>");
        configuration.set("fs.s3a.path.style.access", "true");
        configuration.set("fs.s3a.bucket.probe", "0");
        
        URI baseuri = new URI(
            "s3a://gaia-dr2-parquet"
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

        if (check.isDirectory())
            {
            RemoteIterator<FileStatus> iter = fs.listStatusIterator(basepath);
            while(iter.hasNext())
                {
                FileStatus status = iter.next();
                log.debug("Node [{}]", status.getPath());
                }
            }
        }
    }
