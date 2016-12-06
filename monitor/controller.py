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
                return OUTPUT_FORMAT.format(status=status, entity="XMPP:Server", message=msg)

    @classmethod
    def get_xmpp_server_connections(cls):
        action = "Snh_ShowXmppConnectionReq"
        result = []
        response = cls.make_request(action)
        if response['success']:
            res = response['result']
            if res.status_code in [200]:
                connected_servers = []
                rlist = cls.get_resource_list(res, "connections")
                for r in rlist:
                    connected_servers.append(r.get("name"))
                    if r.get("state") not in ["Established"]:
                        status = STATUS.get("error")
                        msg = "CRITICAL: " + "Connection to Compute Server:{name} is {state}".\
                                format(name=r.get("name",""), state=r.get("state", ""))
                    else:
                        status = STATUS.get("success")
                        msg = "OK: " + "Connection to Compute Server:{name} is {state}".\
                                format(name=r.get("name",""), state=r.get("state", "")) 
                    result.append(OUTPUT_FORMAT.format(status=status, 
                            entity="XMPP:Peer", message=msg))
                result.append(OUTPUT_FORMAT.format(status=STATUS.get("success"), 
                        entity="XMPP:Peers", message=",".join(connected_servers)))
        return result

    @classmethod
    def get_xmpp_peers(cls):
        action = "Snh_SandeshUVECacheReq"
        result = []
        response = cls.make_request(action+"?x=XmppPeerInfoData")
        if response['success']:
            res = response['result']
            if res.status_code in [200]:
                #print res.text 
                root = ET.fromstring(res.text)
                peer_infos = root.findall("XMPPPeerInfo")
                peers_list = []
                for peer_info in peer_infos:
                    data = peer_info.find("data")
                    pinfo_data = data.find("XmppPeerInfoData")
                    identifier = pinfo_data.find("identifier")
                    if identifier is not None:
                        send_state = pinfo_data.find("send_state")
                        send_state_text = send_state.text
                        deleted = pinfo_data.find("deleted")
                        state_info = pinfo_data.find("state_info")
                        pstate_info = state_info.find("PeerStateInfo")
                        state = pstate_info.find("state")
                        state_text = state.text
                        last_state_at = pstate_info.find("last_state_at")
                        if deleted is not None:
                            status = STATUS.get("error")
                            msg = "WARNING: " + "State of Peer:{name} is '{state}, {send_state}'".\
                            format(name=identifier.text, state=state_text, send_state=send_state_text)
                        else:
                            status = STATUS.get("success")
                            msg = "OK: " + "State of Peer:{name} is '{state}, {send_state}'".\
                                format(name=identifier.text, state=state_text, send_state=send_state_text)
                            peers_list.append(identifier.text) 
                        result.append(OUTPUT_FORMAT.format(status=status,
                                entity="XMPP:Peer", message=msg))
                if peers_list:
                    status = STATUS.get("success")
                    msg = ",".join(peers_list)
                else:
                    status = STATUS.get("warning")
                    msg = "WARNING: " + "Could not find XMPP Peers"
                result.append(OUTPUT_FORMAT.format(status=status,
                        entity="XMPP:Peers", message=msg))
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
                connected_peers = []
                for r in rlist:
                    if r.get("encoding") in ["BGP"]:
                        connected_peers.append(r.get("peer"))
                        if r.get("state") not in attrs["state"]["exp_value"] or r.get("send_state") not in attrs["send_state"]["exp_value"]:
                            status = STATUS.get("error")
                            msg = "CRITICAL: " + "State of peer:{name} is changed to '{state}, {send_state}'.".\
                                format(name=r.get("peer",""), state=r.get("state"), send_state=r.get("send_state"))
                        else:
                            status = STATUS.get("success")
                            msg = "OK: " + "State of peer:{name} is '{state}, {send_state}'.".\
                                format(name=r.get("peer",""), state=r.get("state"), send_state=r.get("send_state"))
                        result.append(OUTPUT_FORMAT.format(status=status,
		                entity="Bgp:peer", message=msg))
                if not connected_peers:
                    status = STATUS.get("error")
                    msg = "CRITICAL: " + "Could not find BGP Peers"
                else:
                    status = STATUS.get("success")
                    msg = ",".join(connected_peers)
                result.append(OUTPUT_FORMAT.format(status=status,
                        entity="Bgp:Peers", message=msg))
        return result

class Ifmap(Base):
    @classmethod
    def get_ifmap_connection_status(cls):
        action = "Snh_IFMapPeerServerInfoReq"
        result = []
	host = ""
        conn_sttaus = ""	
        response = cls.make_request(action)
        if response['success']:
            res = response['result']
            if res.status_code in [200]:
                root = ET.fromstring(res.text)
                elem = root.find("server_conn_info")
                if elem is not None:
                    if_elem = elem.find("IFMapPeerServerConnInfo")
                    if if_elem is not None:
                       cs_elem = if_elem.find("connection_status")
                       if cs_elem is not None:
                           conn_status = cs_elem.text
                       h_elem = if_elem.find("host")
                       if h_elem is not None:
                           host = h_elem.text
                       if conn_status and host:
                           if "Up" in conn_status:
                              monit_status_msg = "OK"
                              monit_status = STATUS.get("success")
                           else:
                              monit_status_msg = "CRITICAL"
                              monit_status = STATUS.get("error")
                           msg = "{monit_status_msg}: Connection to Ifmap Server:{host} {conn_status}".\
                                   format(monit_status_msg=monit_status_msg, host=host, conn_status=conn_status)
                           return OUTPUT_FORMAT.format(status=monit_status, entity="IFMAP:Connection", message=msg)

if __name__ == "__main__":
    pipe = [XmppServer.get_xmpp_server_stat,
        XmppServer.get_xmpp_peers,
        BgpPeer.get_bgp_neighbors,
	Ifmap.get_ifmap_connection_status]
    for fun in pipe:
        res = fun()
        if res:
            if isinstance(res, list):
                for r in res:
                    print r
            else:
                print res








