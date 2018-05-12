import salt.cloud
import salt.client
import pprint


class PLServer(object):
    """ the class defining a Prog Leasing server """

    def __init__(self):
        self.name = None
        self.vm_profile = None
        self.salt_states = None
        self.core_count = None
        self.ram = None
        self.vmnet = None
        self.ipaddr = None
        self.gateway = None
        self.template = None
        self.deployed = False
        self.retcode = None
        self.serialnum = None
        self.sys_id = None

    def populate_network(self, ipaddr, gateway):
        """ populate network information """
        self.ipaddr = ipaddr
        self.gateway = gateway

    def populate(self, snowobj):
        """ populate server information from SNOW server ci template """
        self.vm_profile = snowobj.vm_profile
        self.salt_states = snowobj.salt_states
        self.core_count = snowobj.core_count
        self.ram = "{}GB".format(snowobj.ram)
        self.vmnet = snowobj.vmnet
        self.template = snowobj.name_prefix

    def generate_server_name(self):
        # first - we really need to see if there are existing VMs with this name prefix
        client = salt.cloud.CloudClient('/etc/salt/cloud')
        nodes = client.min_query()

        # apparently this query fails silently if vCenter is down, etc
        # so this is a slight tweak to make sure this call fails if we get 0 nodes
        if len(nodes) == 0:
            return

        idmatch = []
        for key, vcsrvr in nodes.iteritems():
            # print("vCenter Server: {}".format(key))
            for subkey, guest in vcsrvr.iteritems():
                for item in guest:
                    # print(item)
                    if self.template in item:
                        idmatch.append(item)

        # if we find no VMs with name_prefix in the name - well - this becomes 01 :)
        vmcount = len(idmatch)
        # the new server id should be count + 1, unless there are gaps (i.e. SERVER01, 02, and 06 exist)
        newid = vmcount + 1

        # now, let's try to make sure that this new ID doesn't exist
        if newid <= 9:
            newname = "{}0{}".format(self.template, newid)
        else:
            newname = "{}{}".format(self.template, newid)

        vmnamematch = 0
        for vm in idmatch:
            if vm == newname:
                vmnamematch = 1

        if vmnamematch == 1:
            # we need to find a new name, that isn't in use
            idint = 1
            # we'll only try this 20 times before giving up
            while idint <= 20:
                if idint <= 9:
                    newname = "{}0{}".format(self.template, idint)
                else:
                    newname = "{}0{}".format(self.template, idint)

                foundvm = 0
                for vm in idmatch:
                    if vm == newname:
                        foundvm = 1

                if foundvm == 0:
                    # found a name we can use - break the loop
                    break
                else:
                    idint = idint + 1

        # at the end of this mess, we have a name we can use!
        self.name = newname

    def build_server(self, snow_sys_id):
        """ tell salt-cloud to build us a server!"""
        # this will control how much information the salt calls below output when building a VM
        # this can be commented out if NO input is preferred...
        from salt.log.setup import setup_console_logger
        setup_console_logger(log_level='info')

        client = salt.cloud.CloudClient('/etc/salt/cloud')
        spec = {'memory': self.ram, 'num_cpus': self.core_count,
                'devices': {'network': {'Network adapter 1': {'name': self.vmnet,
                                                              'ip': self.ipaddr,
                                                              'subnet_mask': '255.255.255.0',
                                                              'gateway': [self.gateway],
                                                              'switch_type': 'distributed',
                                                              'dvs_switch': 'Data dvSwitch'}}},
                'grains': {'salt-cloud-deployed': 'true', 'servertemplateci': self.template,
                           'snow_sys_id': snow_sys_id, 'cmdb-states': self.salt_states}
                }

        s = client.profile(self.vm_profile, names=[self.name], vm_overrides=spec)
        # after build, reset log level or we get a bunch of weird errors that aren't really from Salt
        setup_console_logger(log_level='error')
        # I *THINK* this will give me the IP address, and if it matches what we have assigned, it SHOULD mean the VM
        # has been provisioned and is ready to rock. It would be nice if there was a retcode, but... no luck
        try:
            if s[self.name]['private_ips'][0] == self.ipaddr:
                self.deployed = True
            else:
                self.deployed = False
        except IndexError:
            self.deployed = False
            return

    def get_server(self, name):
        """ get server details from Salt """
        local = salt.client.LocalClient()
        grains = local.cmd(name, 'grains.items')

        # if this was successful, we'll have muchas grains
        if len(grains) == 0:
            # print("No server named {} found.".format(name))
            return
        else:
            # pprint.pprint(grains)
            # sometimes I get an error when running decom_server - I may need to revisit for debugging
            self.name = grains[name]['id']
            # TODO: code needs to handle multiple IP addresses - return as array and have decom_server do heavy lifting
            self.ipaddr = grains[name]['ipv4'][0]
            self.core_count = grains[name]['num_cpus']
            self.ram = grains[name]['mem_total']  # won't match what we get from VMware
            self.serialnum = grains[name]['serialnumber']
            self.sys_id = grains[name]['snow_sys_id']

    def delete_server(self):
        """ delete a server - THIS IS DESTRUCTIVE, DUH! """
        if self.name is None:
            print("Must call get_server first!")
            return
        else:
            client = salt.cloud.CloudClient('/etc/salt/cloud')
            result = client.destroy(self.name)
            # TODO: fix this output
            # right now all the user will see is this:
            # {'lab-vcenter01': {'vmware': {'LAB-SMPLWEB02': True}}}
            # somehow we need to get that "true" value and make sure everything is good
            # but when I try 'print(result[0])' I get an error
            pprint.pprint(result)

    def apply_cmdb_states(self):
        """ apply a salt state to a server based on salt_states and version """
        local = salt.client.LocalClient()
        # parse SNOW template CI for states that belong on this server
        if len(self.salt_states) == 0:
            # there are no states to apply
            print("This CMDB template has no Salt states to apply!")
            self.retcode = 0
            return

        # parse the states we got from CMDB
        parsed_states = self.salt_states.split(";")
        for sub_state in parsed_states:
            state = sub_state.split(":")[0]
            version = sub_state.split(":")[1]
            # there are a few states that have to be run independently for new builds
            # TODO: I wonder if this should be stored in CMDB as part of the salt states payload?
            if state == "states.linux-base":
                for firststate in ['states.linux-base.newminion', 'states.linux-base.yumupdate']:
                    print("Applying initial states for Linux: {}".format(firststate))
                    f_output = local.cmd(self.name, 'state.sls', [firststate],
                                         full_return=True, kwarg=dict(saltenv=version))
                    if f_output[self.name]['retcode'] == 0:
                        print("State {} applied successfully!".format(firststate))
                    else:
                        print("Error executing {}!".format(firststate))
                        print("Lookup salt jid {} for more information!".format(f_output[self.name]['jid']))
                        # this should be a hard fail and drop the user to a command-prompt
                        exit(255)

            print("Applying CMDB states: {} version {}: ".format(state, version))
            state_output = local.cmd(self.name, 'state.sls', [state], full_return=True,
                                     kwarg=dict(saltenv=version))
            if state_output[self.name]['retcode'] == 0:
                print("State {} applied successfully!".format(state))
                self.retcode = state_output[self.name]['retcode']
            else:
                print("Error applying salt state {} -- will not continue!".format(state))
                pprint.pprint(state_output)
                self.retcode = state_output[self.name]['retcode']
                break

        # after all states have finished, reboot the minion (will only reboot if necessary)
        reboot = local.cmd(self.name, 'state.sls', ['states.linux-base.reboot'], full_return=True)
        if reboot[self.name]['retcode'] == 0:
            print("Minion may reboot if new kernel/glibc versions have been installed.")
        else:
            print("Error running reboot.sls - check to see if minion needs reboot for new kernel/glibc!")

    def apply_salt_state(self, state):
        """ apply a single state to a minion. useful for initial minion creation. """
        local = salt.client.LocalClient()
        print("Applying salt state: {}".format(state))
        state_output = local.cmd(self.name, 'state.sls', [state], full_return=True)
        self.retcode = state_output[self.name]['retcode']

    def mark_server_complete(self):
        """
        function should be called only when server build is complete
        right now - this only removes the grain 'newbuild' - but will also eventually need to inform CMDB
        """
        local = salt.client.LocalClient()
        cmd_output = local.cmd(self.name, 'grains.delkey', ['newbuild'], full_return=True)
        self.retcode = cmd_output[self.name]['retcode']
