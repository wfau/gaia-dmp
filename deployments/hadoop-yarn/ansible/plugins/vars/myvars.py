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
# My firsr Ansible vars plugin
#

from ansible.plugins.vars import BaseVarsPlugin

class VarsModule(BaseVarsPlugin):
    REQUIRES_ENABLED = True
    
    def get_vars(self, loader, path, entities, cache=True):
        '''loads some new vars '''
        data = {}

        data['my_entities'] = entities

        data['my_flowers'] = {
            "red":    "rose",
            "yellow": "daff",
            "blue":   "corn"
            }
        
        return data            
            
