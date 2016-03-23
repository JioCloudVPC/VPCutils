#!/usr/bin/env python

import requests
import xml.etree.ElementTree as ET
from pprint import pprint

HOST="127.0.0.1"
PROTOCOL="http"
PORT=8083

STATUS = {"success" : 0,
    "warning" : 1,
    "error" : 2,
     }

OUTPUT_FORMAT = "{status} {entity} - {message}"

class Base(object):
    @classmethod
    def get_resource_list(cls, response, resource_name):
        result = []
        root = ET.fromstring(response.text)
        elem = root.find(resource_name)
        if elem is not None:
            elem = elem.find("list")
            if elem is not None:
                for child in elem:
                    data = {}
                    for c in child:
                        data[c.tag] = c.text
                    result.append(data)
        return result

    @classmethod
    def make_request(cls, action):
        r = None
        try:
            r = requests.get("{protocol}://{host}:{port}/{action}".\
                    format(protocol=PROTOCOL, host=HOST, port=PORT,action=action))
        except Exception as ex:
            return {"result":r, "success":False, "error":ex}
        return {"result":r, "success":True, "error":None}

class XmppServer(Base):
    @classmethod
    def get_xmpp_server_stat(cls):
        action = "Snh_ShowXmppServerReq"
        result = {}
        current_connections = 0
        max_connections = 0
        status = 0
        msg = ""
        response = cls.make_request(action)
        if response['success']:
            res = response['result'] 
            if res.status_code in [200]:
                root = ET.fromstring(res.text)
                elem = root.find("current_connections")
                if elem is not None:
                    current_connections = elem.text
                elem = root.find("max_connections")
                if elem is not None:
                    max_connections = elem.text
                if current_connections >= max_connections:
                    msg = "CRITICAL: " + "current_connections:{c_conn} max_connections:{m_conn}".\
                        format(c_conn=current_connections, m_conn=max_connections)
                    status = STATUS.get("warning")
                else:
                    msg = "OK: " + "current_connections:{c_conn} max_connections:{m_conn}".\
                        format(c_conn=current_connections, m_conn=max_connections)
                    status = STATUS.get("success")
                return OUTPUT_FORMAT.format(status=status, entity="xmpp_server:connection_stat", message=msg)

    @classmethod
    def get_xmpp_server_connections(cls):
        action = "Snh_ShowXmppConnectionReq"
        result = []
        response = cls.make_request(action)
        if response['success']:
            res = response['result']
            if res.status_code in [200]:
                rlist = cls.get_resource_list(res, "connections")
                for r in rlist:
                    if r.get("state") not in ["Established"]:
                        status = STATUS.get("error")
                        msg = "CRITICAL: " + "State of connection:{name} is {state}".\
                                format(name=r.get("name",""), state=r.get("state", ""))
                    else:
                        status = STATUS.get("success")
                        msg = "OK: " + "State of connection:{name} is {state}".\
                                format(name=r.get("name",""), state=r.get("state", "")) 
                    result.append(OUTPUT_FORMAT.format(status=status, 
                            entity="xmpp_server:connection:{name}".format(name=r.get("name","")), message=msg))
        return result

class BgpPeer(Base):
    @classmethod
    def get_bgp_neighbors(cls):
        #stop one contrail-control service to test it.
        action = "Snh_BgpNeighborReq"
	attrs = {"state" : {"exp_value":"Established"},
			"send_state" : {"exp_value":"in sync"}}
        result = []
        response = cls.make_request(action)
        if response['success']:
            res = response['result']
            if res.status_code in [200]:
                rlist = cls.get_resource_list(res, "neighbors")
                for r in rlist:
                    if r.get("encoding") in ["BGP"]:
                        for attr, attr_data in attrs.items():
                            if r.get(attr) not in attr_data["exp_value"]:
                                status = STATUS.get("error")
                                msg = "CRITICAL: " + "{attr} of peer:{name} is changed to '{attr_val}', it should be '{exp_value}'.".\
                                format(attr=attr, name=r.get("peer",""), attr_val=r.get(attr, ""), exp_value=attr_data["exp_value"])
                            else:
                                status = STATUS.get("success")
                                msg = "OK: " + "{attr} of peer:{name} is '{attr_val}'".\
                                    format(attr=attr, name=r.get("peer",""), attr_val=r.get(attr, ""))
                            result.append(OUTPUT_FORMAT.format(status=status,
		                entity="BgpNeighbor:peer:{name}".format(name=r.get("peer","")), message=msg))
        return result

if __name__ == "__main__":
    pipe = [XmppServer.get_xmpp_server_stat,
        XmppServer.get_xmpp_server_connections,
        BgpPeer.get_bgp_neighbors]
    for fun in pipe:
        res = fun()
        if res:
            if isinstance(res, list):
                for r in res:
                    print r
            else:
                print res








