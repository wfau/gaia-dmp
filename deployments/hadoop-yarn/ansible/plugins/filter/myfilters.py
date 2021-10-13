#
# <meta:header>
#   <meta:licence>
#     Copyright (c) 2020, ROE (http://www.roe.ac.uk/)
#
#     This information is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     This information is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.
#   </meta:licence>
# </meta:header>
#
#
# My first Ansible filter plugin.
#

def test_one(string):
    return "Test filter one [%s]" % (string)

def test_two(string):
    return DataObject(string)


class DataObject(object):

    def __init__(self, name):
        self.name = name
        
    def name(self):
        return self.name


class FilterModule(object):
    ''' Ansible jinja2 filters '''

    def filters(self):
        return {
            'test_one': test_one,
            'test_two': test_two
            }


