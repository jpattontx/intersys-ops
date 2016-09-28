#!/usr/bin/python

# List all primary shards that live on the specified server. The output is designed to be fed into other scripts.

# Example 1:
"""
./elasticsearch-listLocalPrimaryShards.py --printOnlyShards --indexName avention_core
5
7
6
9
"""


# Example 2:
"""
./elasticsearch-listLocalPrimaryShards.py --printOnlyIndexes
avention_suggest_fips_county
avention_suggest_it_product_name
avention_suggest_uk_postal_area_code
avention_suggest_city
avention_core
"""

###############################################################################
# Modules

from optparse import OptionParser
import socket
import urllib2
import json


###############################################################################
# Command Line Options

options = {}

parser = OptionParser(usage="usage: %prog [options]",
                      version="%prog 20150630.01")
parser.add_option("-n", "--serverName",
                  action="store",
                  dest="serverName",
                  default=socket.getfqdn(),
                  help="FQDN of the server. If not specified, assumes the server this script is being run on.",)
parser.add_option("-i", "--indexName",
                  action="store",
                  dest="indexName",
                  default="",
                  help="Elasticsearch index name. Requires --printOnlyShards",)
parser.add_option("-p", "--printOnlyIndexes",
                  action="store_true",
                  dest="printOnlyIndexes",
                  default=False,
                  help="Print out index names on the server that contain one or more primary shards",)
parser.add_option("-s", "--printOnlyShards",
                  action="store_true",
                  dest="printOnlyShards",
                  default=False,
                  help="For the given index, print out primary local shards. Requires --indexName",)
parser.add_option("-b", "--printBoth",
                  action="store_true",
                  dest="printBoth",
                  default=False,
                  help="Print out both indexes and shards on the server that contain one or more primary local shards",)
parser.add_option("-f", "--printFullPath",
                  action="store_true",
                  dest="printFullPath",
                  default=False,
                  help="Print out the full path to each index and primary local shard",)
parser.add_option("-z", "--ignoreHealth",
                  action="store_true",
                  dest="ignoreHealth",
                  default=False,
                  help="Ignore the health check",)


(options, args) = parser.parse_args()
cliOptions = options.__dict__


# Not necessary, but makes things more readable
serverName = cliOptions["serverName"]

# If printOnlyShards has been turned on but indexName hasn't been specified, throw an error
if cliOptions["printOnlyShards"] == True and cliOptions["indexName"] == "":
    print "ERROR: --printOnlyIndexes requires --indexName" 

# If indexName has been specified, gratuitously turn on printOnlyShards
if cliOptions["indexName"] != "":
    cliOptions["printOnlyShards"] = True


###############################################################################
# Functions

########################
def checkClusterHealth(esName):
    """Performs a quick health check on the cluster. Grabs the cluster name, verifies that status is greeen and relocating/initializing/unassigned shards is zero """

    # Assemble the url
    esUrl = "http://" + esName + ":9200/_cluster/health"

    # Get the page (JSON)
    esJson = urllib2.urlopen(esUrl).read()

    # Convert the JSON to a dictionary
    esData = json.loads(esJson)

    # Grab the cluster name
    clusterName = esData["cluster_name"]

    # Assume the cluster is healthy
    clusterHealthProblem = 0;

    if esData["status"] != "green":
        print "ERROR - status is", str(esData["status"])
        clusterHealthProblem = 1

    for shardInfo in ["relocating_shards", "initializing_shards", "unassigned_shards"]:
        if esData[shardInfo] != 0:
            print "ERROR -", shardInfo, "is", str(esData[shardInfo])
            clusterHealthProblem = 1

    return (clusterHealthProblem, clusterName)


########################
def findNodeNumber(esName):
    """Converts the server name into the node number"""

    # Assemble the url
    esUrl = "http://" + esName + ":9200/_nodes"

    # Get the page (JSON)
    esJson = urllib2.urlopen(esUrl).read()

    # Convert the JSON to a dictionary
    esData = json.loads(esJson)

    nodeNumber = ""

    for node in esData["nodes"]:
        if esData["nodes"][node]["name"] == esName:
            nodeNumber = node

    if nodeNumber == "":
        print "ERROR - Failed to convert hostname", esName, "into a node number (Must use FQDN)"

    return nodeNumber


########################
def findNodeDataPath(esName, nodeID):
    """Uses the node number to figure out which directory the ES data lives in """

    # Assemble the url
    esUrl = "http://" + esName + ":9200/_nodes?settings=true"

    # Get the page (JSON)
    esJson = urllib2.urlopen(esUrl).read()

    # Convert the JSON to a dictionary
    esData = json.loads(esJson)

    if "path.data" in esData["nodes"][nodeID]["settings"]:
        nodePath = esData["nodes"][nodeID]["settings"]["path.data"]
    else:
        print "ERROR - Failed to determine data path for server", esName, "(Must use FQDN)"
        nodePath = ""

    return nodePath


########################
def printResults(esName, nodeID, nodePath, clusterName, cliOptions):
    """Prints out the local primary shards that are on the server being queried """

    # Assemble the url
    esUrl = "http://" + esName + ":9200/_status"

    # Get the page (JSON)
    esJson = urllib2.urlopen(esUrl).read()

    # Convert the JSON to a dictionary
    esData = json.loads(esJson)

    # Generate an empty dictionary
    localPrimaryShards= {}

    # Loop through every index
    # Todo: bypass Marvel indices. Example: .marvel-2015.01.16
    for indexName in esData["indices"]:

        # Reset the break condition
        discoveredIndex = False

        # For each index, loop through all shards
        for shardNum in esData["indices"][indexName]["shards"]:

            # This hack is here so the index name isn't printed out multiple times (in cases where there are multiple primary shards for a given index)
            if cliOptions["printOnlyIndexes"] == True and discoveredIndex == True:
                break

            # This isn't really necessary, just a performance hack to skip checking shards for indexes we don't care about
            if cliOptions["printOnlyShards"] == True and cliOptions["indexName"] != indexName:
                break

            # For each shard, loop through all instances (1 primary, 0 or more replicas)
            for shardInstance in esData["indices"][indexName]["shards"][shardNum]:

                # If this shard instance is a primary and it is located on this server, print it out
                if shardInstance["routing"]["primary"] == True and shardInstance["routing"]["node"] == nodeID:

                    if cliOptions["printOnlyIndexes"] == True:
                        print indexName
                        discoveredIndex = True
                    elif cliOptions["printOnlyShards"] == True and cliOptions["indexName"] == indexName:
                        print shardNum
                    elif cliOptions["printBoth"] == True:
                        print (indexName + "/" + shardNum)
                    elif cliOptions["printFullPath"] == True:
                        print (nodePath + "/" + clusterName + "/" + "nodes/0/indices/" + indexName + "/" + shardNum)

    return True


###############################################################################
# Main

# Get both the cluster health status and the cluster name
clusterInfo = checkClusterHealth(serverName)

# Not necessary, but makes things more readable
clusterHealthProblem = clusterInfo[0]
clusterName = clusterInfo[1]

if clusterHealthProblem == 0 or cliOptions["ignoreHealth"] == True:
    nodeNumber = findNodeNumber(serverName)

    if cliOptions["printFullPath"] == True:
        nodeDataPath = findNodeDataPath(serverName, nodeNumber)
    else:
        nodeDataPath = ""

    printResults(serverName, nodeNumber, nodeDataPath, clusterName, cliOptions)

###############################################################################
