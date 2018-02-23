#!/bin/bash

KEYCLOAK_USERNAME=$1
KEYCLOAK_PASSWORD=$2
KEYCLOAK_URL=https://keycloak.examle.com
KEYCLOAK_REALM=demo
KEYCLOAK_CLIENT_ID=kubernetes
KEYCLOAK_CLIENT_SECRET=secret

if [ "${KEYCLOAK_USERNAME}" = "" ];then
	read -p "username: " KEYCLOAK_USERNAME
fi
if [ "${KEYCLOAK_PASSWORD}" = "" ];then
	read -sp "password: " KEYCLOAK_PASSWORD
fi

KEYCLOAK_TOKEN_URL=${KEYCLOAK_URL}/auth/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token 

echo
echo "# Getting a token ..."

TOKEN=`curl -s ${KEYCLOAK_TOKEN_URL} \
  -d grant_type=password \
  -d response_type=id_token \
  -d scope=openid \
  -d client_id=${KEYCLOAK_CLIENT_ID} \
  -d client_secret=${KEYCLOAK_CLIENT_SECRET} \
  -d username=${KEYCLOAK_USERNAME} \
  -d password=${KEYCLOAK_PASSWORD}`

RET=$?
if [ "$RET" != "0" ];then
	echo "# Error ($RET) ==> ${TOKEN}";
	exit ${RET}
fi

ERROR=`echo ${TOKEN} | jq .error -r`
if [ "${ERROR}" != "null" ];then
	echo "# Failed ==> ${TOKEN}" >&2
	exit 1
fi

ID_TOKEN=`echo ${TOKEN} | jq .id_token -r`
REFRESH_TOKEN=`echo ${TOKEN} | jq .refresh_token -r`

echo "# Add the following to your \`users:\` in ~/.kube/config  "
echo ""

cat <<EOF
- name: ${KEYCLOAK_USERNAME}
  user:
    auth-provider:
      name: oidc
      config:
        client-id: ${KEYCLOAK_CLIENT_ID}
        client-secret: ${KEYCLOAK_CLIENT_SECRET}
        idp-issuer-url: ${KEYCLOAK_URL}/auth/realms/${KEYCLOAK_REALM}
        id-token: ${ID_TOKEN}
        refresh-token: ${REFRESH_TOKEN}
EOF

echo ""
echo "# if you want to use this user in your context, then"
echo "# $ export CONTEXT_NAME=your-context; export CLUSTER_NAME=your-cluster; kubectl config set-context \${CONTEXT_NAME} --cluster \${CLUSTER_NAME} --user ${KEYCLOAK_USERNAME}"
echo "# if you want to grant \`cluster-admin\` cluster role to this user, then"
echo "# $ kubectl create clusterrolebinding keycloak-user-${KEYCLOAK_USERNAME} --clusterrole=cluster-admin --user=${KEYCLOAK_URL}/auth/realms/${KEYCLOAK_REALM}#${KEYCLOAK_USERNAME}"
echo "# if you want to grant \`admin\` cluster role to this user in a namespace, then"
echo "# $ export NAMESPACE=default; kubectl create rolebinding keycloak-user-\${NAMESPACE}-${KEYCLOAK_USERNAME} --namespace=\${NAMESPACE} --clusterrole=admin --user=${KEYCLOAK_URL}/auth/realms/${KEYCLOAK_REALM}#${KEYCLOAK_USERNAME}"
