#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2017, Noah Sparks <nsparks@outlook.com>
# Copyright: (c) 2015, Hans-Joachim Kliemeck <git@kliemeck.de>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

ANSIBLE_METADATA = {'metadata_version': '1.1',
                    'status': ['preview'],
                    'supported_by': 'core'}


DOCUMENTATION = r'''
---
module: win_acl_inheritance
version_added: "2.1"
short_description: Change ACL inheritance
description:
    - Change ACL (Access Control List) inheritance and optionally copy inherited ACE's (Access Control Entry) to dedicated ACE's or vice versa.
options:
  path:
    description:
      - Path to be used for changing inheritance
    required: true
  state:
    description:
      - Specify whether to enable C(present) or disable C(absent) ACL inheritance
    required: false
    choices:
      - present
      - absent
    default: absent
  reorganize:
    description:
      - For I(state) = C(absent), setting I(reorganize) = C(True) will convert inherited permissions to explicit permissions on the object.
      - For I(state) = C(absent), setting I(reorganize) = C(False) will NOT convert inheritied permissions.
      - For I(state) = C(present), setting I(reorganize) = C(True) will cause explicit permissions that match inherited permissions to be removed.
        This simplifies the ACL list on the object by removing duplicate objects.
      - For I(state) = C(present), setting I(reorganize) = C(False) will enable inheritance of permissions and leave explicit permissions intact.
    required: false
    choices:
      - no
      - yes
    default: false
author:
 - Hans-Joachim Kliemeck (@h0nIg)
 - Noah Sparks (@nwsparks)
'''

EXAMPLES = r'''
- name: Disable inherited ACE's and remove them
  win_acl_inheritance:
    path: C:\apache
    state: absent

- name: Disable and convert inherited ACE's to explicit ACE's
  win_acl_inheritance:
    path: C:\apache
    state: absent
    reorganize: True

- name: Enable and remove dedicated ACE's which are duplicates of inherited ACE's
  win_acl_inheritance:
    path: C:\apache
    state: present
    reorganize: True
'''

RETURN = r'''

'''
